#![cfg_attr(feature = "core-simd", feature(portable_simd))]

mod state;

use core::f32::consts::*;

use glam::f32::*;
use glam::swizzles::*;

use state::{Angles, ExportState, State};

#[link(wasm_import_module = "host")]
extern "C" {
    #[allow(dead_code)]
    fn write(ptr: u32, n: u32);
}

#[allow(dead_code)]
fn write_log(s: &str) {
    let ptr = s.as_ptr() as u32;
    let n = s.len() as u32;

    unsafe {
        write(ptr, n);
    }
}

static mut LAYER1: State = State::new();
static mut LAYER2: State = State::new();
static mut STATE_EXPORT: ExportState = ExportState::new();

#[no_mangle]
pub extern "C" fn init() -> *mut ExportState {
    unsafe {
        LAYER1 = State::new();
        LAYER2 = State::new();
        STATE_EXPORT.import(&LAYER1, &LAYER2);
        &mut STATE_EXPORT as _
    }
}

#[no_mangle]
pub extern "C" fn build() {
    unsafe {
        LAYER1.clear();
        LAYER2.clear();

        build_mesh(&STATE_EXPORT.angles, &mut LAYER1, &mut LAYER2);
        set_data(&mut LAYER1);
        set_data(&mut LAYER2);

        STATE_EXPORT.import(&LAYER1, &LAYER2);
    }
}

#[cfg(not(target_feature = "simd128"))]
fn octahedron_encode(norm: &Vec3) -> (u16, u16) {
    let norm = norm / (norm.x.abs() + norm.y.abs() + norm.z.abs());
    let mut out = norm.xy();
    if norm.z.is_sign_negative() {
        out = (1. - out.yx().abs()) * out.signum();
    }
    out = out * 0.5 + 0.5;
    out = (out * 65535.).clamp(Vec2::ZERO, Vec2::splat(65535.));
    (out.x as _, out.y as _)
}

#[cfg(target_feature = "simd128")]
fn octahedron_encode(norm: &Vec3) -> (u16, u16) {
    use core::arch::wasm32::*;

    let mut norm = f32x4(norm.x, norm.y, norm.z, 0.);
    let mut d = f32x4_abs(norm);
    d = f32x4_add(d, i32x4_shuffle::<2, 3, 0, 0>(d, d));
    d = f32x4_add(d, i32x4_shuffle::<1, 0, 0, 0>(d, d));
    norm = f32x4_div(norm, i32x4_shuffle::<0, 0, 0, 0>(d, d));

    let mut out = f32x4_sub(f32x4_splat(1.), f32x4_abs(norm));
    out = i32x4_shuffle::<0, 5, 1, 4>(norm, out);
    d = i64x2_shl(i64x2_shr(out, 31), 63);
    out = v128_xor(out, d);

    out = f32x4_add(f32x4_mul(out, f32x4_splat(32767.5)), f32x4_splat(32767.5));
    out = u32x4_min(u32x4_trunc_sat_f32x4(out), u32x4_splat(0xffff));

    d = i32x4_ge(norm, i32x4_splat(0));
    d = i32x4_shuffle::<2, 2, 2, 2>(d, d);
    out = v128_bitselect(out, i64x2_shr(out, 32), d);

    (u16x8_extract_lane::<0>(out), u16x8_extract_lane::<4>(out))
}

#[cfg(not(target_feature = "simd128"))]
fn octahedron_tangent_encode(tangent: &Vec4) -> (u16, u16) {
    let d = tangent
        .abs()
        .xyz()
        .to_array()
        .into_iter()
        .sum::<f32>()
        .recip();

    let mut out = tangent.xy() * d;
    if (tangent.z * d).is_sign_negative() {
        out = (1. - out.yx().abs()) * out.signum();
    }
    out = out * 0.5 + 0.5;
    out.y = out.y.max(1. / 32767.) * 0.5 + 0.5;
    if tangent.w.is_sign_negative() {
        out.y = 1. - out.y;
    }

    out = (out * 65535.).clamp(Vec2::ZERO, Vec2::splat(65535.));
    match (out.x as _, out.y as _) {
        (0, 65535) => (65535, 65535),
        v => v,
    }
}

#[cfg(target_feature = "simd128")]
fn octahedron_tangent_encode(tangent: &Vec4) -> (u16, u16) {
    use core::arch::wasm32::*;

    let mut tangent = v128::from(*tangent);
    let mut d = f32x4_abs(i32x4_replace_lane::<3>(tangent, 0));
    d = f32x4_add(d, i32x4_shuffle::<2, 3, 0, 0>(d, d));
    d = f32x4_add(d, i32x4_shuffle::<1, 0, 0, 0>(d, d));
    tangent = f32x4_div(tangent, i32x4_shuffle::<0, 0, 0, 4>(d, f32x4_splat(1.)));

    let mut out = f32x4_sub(f32x4_splat(1.), f32x4_abs(tangent));
    out = i32x4_shuffle::<0, 5, 1, 4>(tangent, out);
    d = i64x2_shl(i64x2_shr(out, 31), 63);
    out = v128_xor(out, d);
    out = f32x4_add(f32x4_mul(out, f32x4_splat(0.5)), f32x4_splat(0.5));

    const C: f32 = 1. / 32767.;
    out = f32x4_max(out, f32x4(f32::NEG_INFINITY, f32::NEG_INFINITY, C, C));
    out = f32x4_mul(out, f32x4(1.0, 1.0, 0.5, 0.5));
    out = f32x4_add(out, f32x4(0.0, 0.0, 0.5, 0.5));
    if i32x4_extract_lane::<3>(tangent) < 0 {
        out = v128_xor(out, i32x4(0, 0, i32::MIN, i32::MIN));
        out = f32x4_add(out, f32x4(0., 0., 1., 1.));
    }

    out = f32x4_mul(out, f32x4_splat(65535.));
    out = u32x4_min(u32x4_trunc_sat_f32x4(out), u32x4_splat(0xffff));

    d = i32x4_ge(tangent, i32x4_splat(0));
    d = i32x4_shuffle::<2, 2, 2, 2>(d, d);
    out = v128_bitselect(out, i64x2_shr(out, 32), d);

    match (u16x8_extract_lane::<0>(out), u16x8_extract_lane::<4>(out)) {
        (0, 65535) => (65535, 65535),
        v => v,
    }
}

fn orthonormalize(basis: &mut Mat3A) {
    let Mat3A {
        x_axis: x,
        y_axis: y,
        z_axis: z,
    } = basis;
    *x = x.normalize();
    *y = (*y - *x * x.dot_into_vec(*y)).normalize();
    *z = (*z - *x * x.dot_into_vec(*z) - *y * y.dot_into_vec(*z)).normalize();
}

const ONEISH: f32 = 1.0 - 1e-6;

fn get_angle_x(basis: &Mat3A) -> f32 {
    let t = basis.z_axis[0];
    if (-ONEISH..=ONEISH).contains(&t) {
        if (basis.y_axis == Vec3A::new(0., 1., 0.))
            && (basis.x_axis[1] == 0.)
            && (basis.z_axis[1] == 0.)
        {
            0.
        } else {
            (-basis.z_axis[1]).atan2(basis.z_axis[2])
        }
    } else {
        basis.y_axis[2].atan2(basis.y_axis[1])
    }
}

fn euler_angle_yxz(basis: &Mat3A) -> Vec3 {
    let t = basis.z_axis[1];
    if (-ONEISH..=ONEISH).contains(&t) {
        if (basis.x_axis == Vec3A::new(1., 0., 0.))
            && (basis.y_axis[0] == 0.)
            && (basis.z_axis[0] == 0.)
        {
            vec3((-t).atan2(basis.y_axis[1]), 0., 0.)
        } else {
            vec3(
                (-t).asin(),
                basis.z_axis[0].atan2(basis.z_axis[2]),
                basis.x_axis[1].atan2(basis.y_axis[1]),
            )
        }
    } else if t.is_sign_positive() {
        vec3(-FRAC_PI_2, -basis.y_axis[0].atan2(basis.x_axis[0]), 0.)
    } else {
        vec3(FRAC_PI_2, basis.y_axis[0].atan2(basis.x_axis[0]), 0.)
    }
}

fn euler_angle_xyx(basis: &Mat3A) -> Vec3 {
    let t = basis.x_axis[0];
    if (-ONEISH..=ONEISH).contains(&t) {
        vec3(
            basis.y_axis[0].atan2(-basis.z_axis[0]),
            t.acos(),
            basis.x_axis[1].atan2(basis.x_axis[2]),
        )
    } else if t.is_sign_positive() {
        vec3(basis.z_axis[1].atan2(basis.y_axis[1]), 0., 0.)
    } else {
        vec3((-basis.z_axis[1]).atan2(basis.y_axis[1]), PI, 0.)
    }
}

fn euler_angle_yxy(basis: &Mat3A) -> Vec3 {
    let t = basis.y_axis[1];
    if (-ONEISH..=ONEISH).contains(&t) {
        vec3(
            basis.x_axis[1].atan2(basis.z_axis[1]),
            t.acos(),
            basis.y_axis[0].atan2(-basis.y_axis[2]),
        )
    } else if t.is_sign_positive() {
        vec3(basis.x_axis[2].atan2(basis.x_axis[0]), 0., 0.)
    } else {
        vec3((-basis.x_axis[2]).atan2(basis.x_axis[0]), 0., 0.)
    }
}

fn draw_quad(
    state: &mut State,
    points: &[Vec3A; 4],
    normal: &Vec3A,
    tangent: &Vec4,
    uv: Vec2,
    mut duv: Vec2,
) {
    let normal = (*normal).into();
    let i = state.len() as u32;

    let Vec2 { x: x1, y: y1 } = uv;
    duv += uv;
    let Vec2 { x: x2, y: y2 } = duv;
    state.add_vertices(
        points
            .iter()
            .map(|&v| Vec3::from(v))
            .zip([uv, vec2(x2, y1), vec2(x1, y2), duv])
            .map(move |(v, uv)| (v, normal, *tangent, uv)),
    );

    state.add_indices([i, i + 3, i + 1, i, i + 2, i + 3]);
}

fn draw_quad_subdiv(
    state: &mut State,
    [p00, p01, p10, p11]: &[Vec3A; 4],
    normal: &Vec3A,
    tangent: &Vec4,
    uv: Vec2,
    duv: Vec2,
    (sx, sy): (usize, usize),
    subdiv_shift: bool,
) {
    let normal = (*normal).into();
    let i = state.len();

    let ssx = subdiv_shift && (sx & 1 != 0);
    let ssy = subdiv_shift && (sy & 1 != 0);

    let sx_ = sx as f32;
    let sy_ = sy as f32;

    let ex = (sx + 3) / 2;
    for mut y in 0..(sy + 3) / 2 {
        y *= 2;
        y = if ssy { y.saturating_sub(1) } else { y.min(sy) };

        let dy = y as f32 / sy_;
        let p0 = p00.lerp(*p10, dy);
        let p1 = p01.lerp(*p11, dy);
        let dv = uv.y + duv.y * dy;

        state.add_vertices((0..ex).map(|mut x| {
            x *= 2;
            x = if ssx { x.saturating_sub(1) } else { x.min(sx) };

            let dx = x as f32 / sx_;

            (
                p0.lerp(p1, dx).into(),
                normal,
                *tangent,
                vec2(uv.x + duv.x * dx, dv),
            )
        }));
    }

    for y in 0..(sy + 1) / 2 {
        let j = i + y * ex;
        for x in 0..(sx + 1) / 2 {
            let j = j + x;
            state.add_indices(
                [j, j + 1, j + ex + 1, j, j + ex + 1, j + ex]
                    .into_iter()
                    .map(|v| v as u32),
            );
        }
    }
}

fn draw_cube(
    state: &mut State,
    transform: &Affine3A,
    start: &Vec3A,
    end: &Vec3A,
    uv: Vec2,
    dim: Vec3,
) {
    let Affine3A {
        matrix3: basis,
        translation: origin,
    } = transform;

    let sx = basis.x_axis * start.xxx();
    let sy = basis.y_axis * start.yyy();
    let sz = basis.z_axis * start.zzz();
    let ex = basis.x_axis * end.xxx();
    let ey = basis.y_axis * end.yyy();
    let ez = basis.z_axis * end.zzz();

    let p000 = *origin + sx + sy + sz;
    let p001 = *origin + sx + sy + ez;
    let p010 = *origin + sx + ey + sz;
    let p011 = *origin + sx + ey + ez;
    let p100 = *origin + ex + sy + sz;
    let p101 = *origin + ex + sy + ez;
    let p110 = *origin + ex + ey + sz;
    let p111 = *origin + ex + ey + ez;

    // Front
    draw_quad(
        &mut *state,
        &[p001, p101, p011, p111],
        &basis.z_axis,
        &basis.x_axis.extend(1.),
        vec2(uv.x + dim.z, uv.y + dim.z + dim.y),
        vec2(dim.x, -dim.y),
    );
    // Back
    draw_quad(
        &mut *state,
        &[p100, p000, p110, p010],
        &-basis.z_axis,
        &(-basis.x_axis).extend(1.),
        vec2(uv.x + dim.z * 2. + dim.x, uv.y + dim.z + dim.y),
        vec2(dim.x, -dim.y),
    );
    // Left
    draw_quad(
        &mut *state,
        &[p000, p001, p010, p011],
        &-basis.x_axis,
        &basis.z_axis.extend(-1.),
        vec2(uv.x, uv.y + dim.z + dim.y),
        vec2(dim.z, -dim.y),
    );
    // Right
    draw_quad(
        &mut *state,
        &[p101, p100, p111, p110],
        &basis.x_axis,
        &(-basis.z_axis).extend(-1.),
        vec2(uv.x + dim.z + dim.x, uv.y + dim.z + dim.y),
        vec2(dim.z, -dim.y),
    );
    // Up
    draw_quad(
        &mut *state,
        &[p011, p111, p010, p110],
        &basis.y_axis,
        &basis.x_axis.extend(-1.),
        vec2(uv.x + dim.z, uv.y + dim.z),
        vec2(dim.x, -dim.z),
    );
    // Down
    draw_quad(
        &mut *state,
        &[p000, p100, p001, p101],
        &-basis.y_axis,
        &basis.x_axis.extend(-1.),
        vec2(uv.x + dim.z + dim.x, uv.y),
        vec2(dim.x, dim.z),
    );
}

fn draw_single_joint(
    state: &mut State,
    transform: &Affine3A,
    r: f32,
    uv: Vec2,
    dim: Vec3,
    scale: f32,
    (sx, sy, sz): (usize, usize, usize),
) {
    let Affine3A {
        matrix3: basis,
        translation: origin,
    } = transform;
    let Vec2 { x: u, y: v } = uv;
    let Vec3 {
        x: dx,
        y: dy_,
        z: dz,
    } = dim;

    // Trig prep
    let (s, c) = r.sin_cos();
    let t = (r * 0.5).tan() * scale;

    // Cutting plane
    // Lots of unwrapping here to ensure efficiency
    let bx = basis.x_axis * scale;
    let by = basis.y_axis * t;
    let bz = basis.z_axis * scale;
    let m00 = *origin - bx + (by - bz);
    let m01 = *origin - bx - (by - bz);
    let m10 = *origin + bx + (by - bz);
    let m11 = *origin + bx - (by - bz);

    let dy = dy_ * 0.5;

    // Draw bottom
    {
        // Bottom plane
        let by = basis.y_axis;
        let b00 = *origin + by - bx - bz;
        let b01 = *origin + by - bx + bz;
        let b10 = *origin + by + bx - bz;
        let b11 = *origin + by + bx + bz;

        // Front
        draw_quad_subdiv(
            &mut *state,
            &[b01, b11, m01, m11],
            &basis.z_axis,
            &basis.x_axis.extend(1.),
            vec2(u + dz, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[b10, b00, m10, m00],
            &-basis.z_axis,
            &(-basis.x_axis).extend(1.),
            vec2(u + dz * 2. + dx, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[b00, b01, m00, m01],
            &-basis.x_axis,
            &basis.z_axis.extend(-1.),
            vec2(u, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[b11, b10, m11, m10],
            &basis.x_axis,
            &(-basis.z_axis).extend(-1.),
            vec2(u + dz + dx, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
    }

    // Draw top
    {
        // Top plane
        let basis = Mat3A::from_cols(
            basis.x_axis,
            basis.y_axis * c + basis.z_axis * s,
            basis.z_axis * c - basis.y_axis * s,
        );
        let bx = basis.x_axis * scale;
        let by = basis.y_axis;
        let bz = basis.z_axis * scale;
        let t00 = *origin - by - bx - bz;
        let t01 = *origin - by - bx + bz;
        let t10 = *origin - by + bx - bz;
        let t11 = *origin - by + bx + bz;

        // Front
        draw_quad_subdiv(
            &mut *state,
            &[m01, m11, t01, t11],
            &basis.z_axis,
            &basis.x_axis.extend(1.),
            vec2(u + dz, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[m10, m00, t10, t00],
            &-basis.z_axis,
            &(-basis.x_axis).extend(1.),
            vec2(u + dz * 2. + dx, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[m00, m01, t00, t01],
            &-basis.x_axis,
            &basis.z_axis.extend(-1.),
            vec2(u, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[m11, m10, t11, t10],
            &basis.x_axis,
            &(-basis.z_axis).extend(-1.),
            vec2(u + dz + dx, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
    }
}

fn draw_double_joint(
    state: &mut State,
    transform: &Affine3A,
    r: Vec3,
    uv: Vec2,
    dim: Vec3,
    right_handed: bool,
    scale: f32,
    (sx, sy, sz): (usize, usize, usize),
) {
    let Affine3A {
        matrix3: basis,
        translation: origin,
    } = transform;
    let Vec2 { x: u, y: v } = uv;
    let Vec3 {
        x: dx,
        y: dy_,
        z: dz,
    } = dim;

    // Rotate
    let (s, c) = (r.x + r.z).sin_cos();
    let basis = Mat3A::from_cols(
        basis.x_axis * c + basis.z_axis * s,
        basis.y_axis,
        basis.z_axis * c - basis.x_axis * s,
    );

    // Trig prep
    let (s, c) = r.x.sin_cos();
    let mut t = (r.y * 0.5).tan() * scale;
    if !right_handed {
        t = -t;
    }

    // Cutting plane
    // Lots of unwrapping here to ensure efficiency
    let bx = basis.x_axis * scale;
    let by1 = basis.y_axis * ((s + c) * t);
    let by2 = basis.y_axis * ((s - c) * t);
    let bz = basis.z_axis * scale;
    let m00 = *origin - bx - by1 - bz;
    let m01 = *origin - bx - by2 + bz;
    let m10 = *origin + bx + by2 - bz;
    let m11 = *origin + bx + by1 + bz;

    let dy = dy_ * 0.5;

    // Draw bottom
    {
        // Bottom plane
        let by = basis.y_axis * (SQRT_2 * scale);
        let b00 = *origin + by - bx - bz;
        let b01 = *origin + by - bx + bz;
        let b10 = *origin + by + bx - bz;
        let b11 = *origin + by + bx + bz;

        // Front
        draw_quad_subdiv(
            &mut *state,
            &[b01, b11, m01, m11],
            &basis.z_axis,
            &basis.x_axis.extend(1.),
            vec2(u + dz, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[b10, b00, m10, m00],
            &-basis.z_axis,
            &(-basis.x_axis).extend(1.),
            vec2(u + dz * 2. + dx, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[b00, b01, m00, m01],
            &-basis.x_axis,
            &basis.z_axis.extend(-1.),
            vec2(u, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[b11, b10, m11, m10],
            &basis.x_axis,
            &(-basis.z_axis).extend(-1.),
            vec2(u + dz + dx, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Up
        draw_quad(
            &mut *state,
            &[b01, b11, b00, b10],
            &basis.y_axis,
            &basis.x_axis.extend(-1.),
            vec2(u + dz, v + dz),
            vec2(dx, -dz),
        );
    }

    // Draw top
    {
        // Top plane
        let basis = basis
            * Mat3A::from_axis_angle(
                if right_handed {
                    vec3(-c, 0., s)
                } else {
                    vec3(c, 0., -s)
                },
                r.y,
            );
        let by = basis.y_axis * -SQRT_2;
        let bx = basis.x_axis * scale;
        let bz = basis.z_axis * scale;
        let t00 = *origin + by - bx - bz;
        let t01 = *origin + by - bx + bz;
        let t10 = *origin + by + bx - bz;
        let t11 = *origin + by + bx + bz;

        // Front
        draw_quad_subdiv(
            &mut *state,
            &[m01, m11, t01, t11],
            &basis.z_axis,
            &basis.x_axis.extend(1.),
            vec2(u + dz, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[m10, m00, t10, t00],
            &-basis.z_axis,
            &(-basis.x_axis).extend(1.),
            vec2(u + dz * 2. + dx, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[m00, m01, t00, t01],
            &-basis.x_axis,
            &basis.z_axis.extend(-1.),
            vec2(u, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[m11, m10, t11, t10],
            &basis.x_axis,
            &(-basis.z_axis).extend(-1.),
            vec2(u + dz + dx, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
    }
}

fn draw_hand(state: &mut State, transform: &Affine3A, uv: Vec2, uv_top: Vec2, scale: f32) {
    let Affine3A {
        matrix3: basis,
        translation: origin,
    } = transform;
    let Vec2 { x: u, y: v } = uv;

    let Mat3A {
        x_axis: bx,
        y_axis: by,
        z_axis: bz,
    } = basis.mul_scalar(scale);

    let p000 = *origin - bx - by - bz;
    let p001 = *origin - bx - by + bz;
    let p010 = *origin - bx + by - bz;
    let p011 = *origin - bx + by + bz;
    let p100 = *origin + bx - by - bz;
    let p101 = *origin + bx - by + bz;
    let p110 = *origin + bx + by - bz;
    let p111 = *origin + bx + by + bz;

    const D: f32 = 4. / 64.;
    // Front
    draw_quad(
        &mut *state,
        &[p001, p101, p011, p111],
        &basis.z_axis,
        &basis.x_axis.extend(1.),
        vec2(u + D, v + D * 2.),
        vec2(D, -D),
    );
    // Back
    draw_quad(
        &mut *state,
        &[p100, p000, p110, p010],
        &-basis.z_axis,
        &(-basis.x_axis).extend(1.),
        vec2(u + D * 3., v + D * 2.),
        vec2(D, -D),
    );
    // Left
    draw_quad(
        &mut *state,
        &[p000, p001, p010, p011],
        &-basis.x_axis,
        &basis.z_axis.extend(-1.),
        vec2(u, v + D * 2.),
        vec2(D, -D),
    );
    // Right
    draw_quad(
        &mut *state,
        &[p101, p100, p111, p110],
        &basis.x_axis,
        &(-basis.z_axis).extend(-1.),
        vec2(u + D * 2., v + D * 2.),
        vec2(D, -D),
    );
    // Down
    draw_quad(
        &mut *state,
        &[p000, p100, p001, p101],
        &-basis.y_axis,
        &basis.x_axis.extend(-1.),
        uv_top,
        vec2(D, D),
    );
}

fn build_mesh(input: &Angles, layer1: &mut State, layer2: &mut State) {
    let subdiv = (8, 4, 8);
    let use_layer2 = input.draw_layer2 != 0;
    let l2_offv = Vec3A::splat(input.layer2_off);

    let mut t_;
    let mut t;
    let mut r;
    let mut r_;

    // Draw body
    draw_cube(
        &mut *layer1,
        &Affine3A::IDENTITY,
        &Vec3A::new(-4., -10., -2.),
        &Vec3A::new(4., 2., 2.),
        vec2(16., 16.) / 64.,
        vec3(8., 12., 4.) / 64.,
    );
    if use_layer2 {
        draw_cube(
            &mut *layer2,
            &Affine3A::IDENTITY,
            &(Vec3A::new(-4., -10., -2.) - l2_offv),
            &(Vec3A::new(4., 2., 2.) + l2_offv),
            vec2(16., 32.) / 64.,
            vec3(8., 12., 4.) / 64.,
        );
    }

    // Draw head
    t = Affine3A::from_mat3_translation(input.head_basis, Vec3::new(0., 2., 0.));
    orthonormalize(&mut t.matrix3);
    r = euler_angle_yxz(&t.matrix3);
    t.matrix3 = Mat3A::from_quat(
        Quat::from_rotation_y(r.y) * Quat::from_rotation_x(r.x.clamp(-FRAC_PI_2, FRAC_PI_2)),
    );

    draw_cube(
        &mut *layer1,
        &t,
        &Vec3A::new(-4., 0., -4.),
        &Vec3A::new(4., 8., 4.),
        vec2(0., 0.) / 64.,
        vec3(8., 8., 8.) / 64.,
    );
    if use_layer2 {
        draw_cube(
            &mut *layer2,
            &t,
            &(Vec3A::new(-4., 0., -4.) - l2_offv),
            &(Vec3A::new(4., 8., 4.) + l2_offv),
            vec2(32., 0.) / 64.,
            vec3(8., 8., 8.) / 64.,
        );
    }

    // Draw left arm
    t = Affine3A::from_cols(
        -Vec3A::from(input.larm_basis.y_axis),
        input.larm_basis.x_axis.into(),
        input.larm_basis.z_axis.into(),
        Vec3A::new(SQRT_2 * 2. + 4., 0., 0.),
    );
    orthonormalize(&mut t.matrix3);
    r = -euler_angle_xyx(&t.matrix3);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    t.matrix3 = Mat3A::from_quat(
        Quat::from_rotation_x(r.z) * Quat::from_rotation_y(r.y) * Quat::from_rotation_x(r.x),
    );
    (t.matrix3.x_axis, t.matrix3.y_axis) = (t.matrix3.y_axis, -t.matrix3.x_axis);
    t_ = Affine3A::from_cols(
        Vec3A::new(0., 2., 0.),
        Vec3A::new(-2., 0., 0.),
        Vec3A::new(0., 0., 2.),
        t.translation,
    );
    t.translation += t.matrix3.y_axis * ((SQRT_2 + 1.) * -2.);

    draw_double_joint(
        &mut *layer1,
        &t_,
        r,
        vec2(32., 48.) / 64.,
        vec3(4., 4., 4.) / 64.,
        false,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_double_joint(
            &mut *layer2,
            &t_,
            r,
            vec2(48., 48.) / 64.,
            vec3(4., 4., 4.) / 64.,
            false,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw left elbow
    t_ = Affine3A {
        matrix3: input.lelbow_basis.into(),
        translation: t.translation,
    };
    orthonormalize(&mut t_.matrix3);
    r_ = get_angle_x(&t_.matrix3).clamp(-FRAC_PI_2, FRAC_PI_2);
    t_.matrix3 = t.matrix3 * 2.;
    t.matrix3 *= Mat3A::from_rotation_x(r_);
    t.translation += t.matrix3.y_axis * -4.;

    draw_single_joint(
        &mut *layer1,
        &t_,
        r_,
        vec2(32., 52.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &t_,
            r_,
            vec2(48., 52.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw left hand
    draw_hand(
        &mut *layer1,
        &t,
        vec2(32., 56.) / 64.,
        vec2(40., 48.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &t,
            vec2(48., 56.) / 64.,
            vec2(56., 48.) / 64.,
            2. + input.layer2_off,
        );
    }

    // Draw right arm
    t = Affine3A::from_cols(
        input.rarm_basis.y_axis.into(),
        -Vec3A::from(input.rarm_basis.x_axis),
        input.rarm_basis.z_axis.into(),
        Vec3A::new(SQRT_2 * -2. - 4., 0., 0.),
    );
    orthonormalize(&mut t.matrix3);
    r = euler_angle_xyx(&t.matrix3);
    r.y = -r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    t.matrix3 = Mat3A::from_quat(
        Quat::from_rotation_x(-r.z) * Quat::from_rotation_y(r.y) * Quat::from_rotation_x(-r.x),
    );
    (t.matrix3.x_axis, t.matrix3.y_axis) = (-t.matrix3.y_axis, t.matrix3.x_axis);
    t_ = Affine3A::from_cols(
        Vec3A::new(0., -2., 0.),
        Vec3A::new(2., 0., 0.),
        Vec3A::new(0., 0., 2.),
        t.translation,
    );
    t.translation += t.matrix3.y_axis * ((SQRT_2 + 1.) * -2.);

    draw_double_joint(
        &mut *layer1,
        &t_,
        r,
        vec2(40., 16.) / 64.,
        vec3(4., 4., 4.) / 64.,
        true,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_double_joint(
            &mut *layer2,
            &t_,
            r,
            vec2(40., 32.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw right elbow
    t_ = Affine3A {
        matrix3: input.relbow_basis.into(),
        translation: t.translation,
    };
    orthonormalize(&mut t_.matrix3);
    r_ = get_angle_x(&t_.matrix3).clamp(-FRAC_PI_2, FRAC_PI_2);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    t_.matrix3 = t.matrix3 * 2.;
    t.matrix3 *= Mat3A::from_rotation_x(r_);
    t.translation += t.matrix3.y_axis * -4.;

    draw_single_joint(
        &mut *layer1,
        &t_,
        r_,
        vec2(40., 20.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &t_,
            r_,
            vec2(40., 36.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw right hand
    draw_hand(
        &mut *layer1,
        &t,
        vec2(40., 24.) / 64.,
        vec2(48., 16.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &t,
            vec2(40., 40.) / 64.,
            vec2(48., 32.) / 64.,
            2. + input.layer2_off,
        );
    }

    // Draw left leg
    t = Affine3A::from_mat3_translation(input.lleg_basis, Vec3::new(2., SQRT_2 * -2. - 10., 0.));
    orthonormalize(&mut t.matrix3);
    r = euler_angle_yxy(&t.matrix3);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    t_ = Affine3A::from_cols(
        Vec3A::new(2., 0., 0.),
        Vec3A::new(0., 2., 0.),
        Vec3A::new(0., 0., 2.),
        t.translation,
    );
    t.matrix3 = Mat3A::from_quat(
        Quat::from_rotation_y(-r.z) * Quat::from_rotation_x(-r.y) * Quat::from_rotation_y(-r.x),
    );
    t.translation += t.matrix3.y_axis * ((SQRT_2 + 1.) * -2.);

    draw_double_joint(
        &mut *layer1,
        &t_,
        r,
        vec2(16., 48.) / 64.,
        vec3(4., 4., 4.) / 64.,
        true,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_double_joint(
            &mut *layer2,
            &t_,
            r,
            vec2(0., 48.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw left knee
    t_ = Affine3A {
        matrix3: input.lknee_basis.into(),
        translation: t.translation,
    };
    orthonormalize(&mut t_.matrix3);
    r_ = get_angle_x(&t_.matrix3).clamp(-FRAC_PI_2, FRAC_PI_2);
    t_.matrix3 = t.matrix3 * 2.;
    t.matrix3 *= Mat3A::from_rotation_x(r_);
    t.translation += t.matrix3.y_axis * -4.;

    draw_single_joint(
        &mut *layer1,
        &t_,
        r_,
        vec2(16., 52.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &t_,
            r_,
            vec2(0., 52.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw left foot
    draw_hand(
        &mut *layer1,
        &t,
        vec2(16., 56.) / 64.,
        vec2(24., 48.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &t,
            vec2(0., 56.) / 64.,
            vec2(8., 48.) / 64.,
            2. + input.layer2_off,
        );
    }

    // Draw right leg
    t = Affine3A::from_mat3_translation(input.rleg_basis, Vec3::new(-2., SQRT_2 * -2. - 10., 0.));
    orthonormalize(&mut t.matrix3);
    r = euler_angle_yxy(&t.matrix3);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    t_ = Affine3A::from_cols(
        Vec3A::new(2., 0., 0.),
        Vec3A::new(0., 2., 0.),
        Vec3A::new(0., 0., 2.),
        t.translation,
    );
    t.matrix3 = Mat3A::from_quat(
        Quat::from_rotation_y(-r.z) * Quat::from_rotation_x(-r.y) * Quat::from_rotation_y(-r.x),
    );
    t.translation += t.matrix3.y_axis * ((SQRT_2 + 1.) * -2.);

    draw_double_joint(
        &mut *layer1,
        &t_,
        r,
        vec2(0., 16.) / 64.,
        vec3(4., 4., 4.) / 64.,
        true,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_double_joint(
            &mut *layer2,
            &t_,
            r,
            vec2(0., 32.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw right knee
    t_ = Affine3A {
        matrix3: input.rknee_basis.into(),
        translation: t.translation,
    };
    orthonormalize(&mut t_.matrix3);
    r_ = get_angle_x(&t_.matrix3).clamp(-FRAC_PI_2, FRAC_PI_2);
    t_.matrix3 = t.matrix3 * 2.;
    t.matrix3 *= Mat3A::from_rotation_x(r_);
    t.translation += t.matrix3.y_axis * -4.;

    draw_single_joint(
        &mut *layer1,
        &t_,
        r_,
        vec2(0., 20.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &t_,
            r_,
            vec2(0., 36.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + input.layer2_off / 2.,
            subdiv,
        );
    }

    // Draw right foot
    draw_hand(
        &mut *layer1,
        &t,
        vec2(0., 24.) / 64.,
        vec2(8., 16.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &t,
            vec2(0., 40.) / 64.,
            vec2(8., 32.) / 64.,
            2. + input.layer2_off,
        );
    }
}

fn set_data(state: &mut State) {
    state.set_vertex_data(|vertex, normal, tangent| {
        vertex
            .iter()
            .flat_map(|v| v.to_array())
            .flat_map(|v| v.to_le_bytes())
            .chain(
                normal
                    .iter()
                    .zip(tangent)
                    .flat_map(|(n, t)| {
                        let (xn, yn) = octahedron_encode(n);
                        let (xt, yt) = octahedron_tangent_encode(t);
                        [xn, yn, xt, yt]
                    })
                    .flat_map(|v| v.to_le_bytes()),
            )
    });
    state.set_attr_data(|uv| {
        uv.iter()
            .flat_map(|uv| uv.to_array())
            .flat_map(|v| v.to_le_bytes())
    });
}
