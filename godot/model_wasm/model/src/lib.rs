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

fn octahedron_encode(mut norm: Vec3) -> (u16, u16) {
    norm *= (norm.x.abs() + norm.y.abs() + norm.z.abs()).recip();
    let mut out = vec2(norm.x, norm.y);
    if norm.z.is_sign_negative() {
        out = (Vec2::ONE - out.yx()) * out.signum();
    }
    out = out * 0.5 + 0.5;
    out = (out * 65535.).clamp(Vec2::ZERO, Vec2::splat(65535.));
    (out.x as _, out.y as _)
}

fn octahedron_tangent_encode(tangent: Vec4) -> (u16, u16) {
    let [x, y, z, w] = tangent.to_array();
    let d = (x.abs() + y.abs() + z.abs()).recip();

    let mut out = vec2(x, y) * d;
    if (z * d).is_sign_negative() {
        out = (Vec2::ONE - out.yx()) * out.signum();
    }
    out = out * 0.5 + 0.5;
    out.y = out.y.max(1. / 32767.) * 0.5 + 0.5;
    if w.is_sign_negative() {
        out.y = 1. - out.y;
    }

    out = (out * 65535.).clamp(Vec2::ZERO, Vec2::splat(65535.));
    match (out.x as _, out.y as _) {
        (0, 65535) => (65535, 65535),
        v => v,
    }
}

fn orthonormalize(basis: &mut Mat3) {
    let Mat3 {
        x_axis: x,
        y_axis: y,
        z_axis: z,
    } = basis;
    *x = x.normalize();
    *y = (*y - *x * x.dot(*y)).normalize();
    *z = (*z - *x * x.dot(*z) - *y * y.dot(*z)).normalize();
}

const ONEISH: f32 = 1.0 - 1e-6;

fn get_angle_x(basis: &Mat3) -> f32 {
    let c2 = basis.z_axis.x;
    if (-ONEISH..=ONEISH).contains(&c2) {
        if (basis.y_axis.y == 1.)
            && (basis.y_axis.x == 0.)
            && (basis.x_axis.y == 0.)
            && (basis.z_axis.y == 0.)
            && (basis.y_axis.z == 0.)
        {
            0.
        } else {
            (-basis.z_axis.y).atan2(basis.z_axis.z)
        }
    } else {
        basis.y_axis.z.atan2(basis.y_axis.y)
    }
}

fn euler_angle_yxz(basis: &Mat3) -> Vec3 {
    let c2 = basis.z_axis.y;
    if (-ONEISH..=ONEISH).contains(&c2) {
        if (basis.x_axis.x == 1.)
            && (basis.y_axis.x == 0.)
            && (basis.x_axis.y == 0.)
            && (basis.z_axis.x == 0.)
            && (basis.x_axis.z == 0.)
        {
            vec3((-c2).atan2(basis.y_axis.y), 0., 0.)
        } else {
            vec3(
                (-c2).asin(),
                basis.z_axis.x.atan2(basis.z_axis.z),
                basis.x_axis.y.atan2(basis.y_axis.y),
            )
        }
    } else if c2.is_sign_positive() {
        vec3(-FRAC_PI_2, -basis.y_axis.x.atan2(basis.x_axis.x), 0.)
    } else {
        vec3(FRAC_PI_2, basis.y_axis.x.atan2(basis.x_axis.x), 0.)
    }
}

fn euler_angle_xyx(basis: &Mat3) -> Vec3 {
    let c2 = basis.x_axis.x;
    if (-ONEISH..=ONEISH).contains(&c2) {
        vec3(
            basis.y_axis.x.atan2(-basis.z_axis.x),
            c2.acos(),
            basis.x_axis.y.atan2(basis.x_axis.z),
        )
    } else if c2.is_sign_positive() {
        vec3(basis.z_axis.y.atan2(basis.y_axis.y), 0., 0.)
    } else {
        vec3((-basis.z_axis.y).atan2(basis.y_axis.y), PI, 0.)
    }
}

fn euler_angle_yxy(basis: &Mat3) -> Vec3 {
    let c2 = basis.y_axis.y;
    if (-ONEISH..=ONEISH).contains(&c2) {
        vec3(
            basis.x_axis.y.atan2(basis.z_axis.y),
            c2.acos(),
            basis.y_axis.x.atan2(-basis.y_axis.z),
        )
    } else if c2.is_sign_positive() {
        vec3(basis.x_axis.z.atan2(basis.x_axis.x), 0., 0.)
    } else {
        vec3((-basis.x_axis.z).atan2(basis.x_axis.x), 0., 0.)
    }
}

fn draw_quad(
    state: &mut State,
    points: &[Vec3; 4],
    mut normal: Vec3,
    mut tangent: Vec4,
    uv: Vec2,
    mut duv: Vec2,
) {
    normal = normal.normalize();
    tangent = Vec4::from((tangent.xyz().normalize(), tangent.w));
    let i = state.len() as u32;

    let Vec2 { x: x1, y: y1 } = uv;
    duv += uv;
    let Vec2 { x: x2, y: y2 } = duv;
    state.add_vertices(
        points
            .iter()
            .copied()
            .zip([uv, vec2(x2, y1), vec2(x1, y2), duv])
            .map(move |(v, uv)| (v, normal, tangent, uv)),
    );

    state.add_indices([i, i + 3, i + 1, i, i + 2, i + 3]);
}

fn draw_quad_subdiv(
    state: &mut State,
    [p00, p01, p10, p11]: &[Vec3; 4],
    mut normal: Vec3,
    mut tangent: Vec4,
    uv: Vec2,
    duv: Vec2,
    (sx, sy): (usize, usize),
    subdiv_shift: bool,
) {
    normal = normal.normalize();
    tangent = Vec4::from((tangent.xyz().normalize(), tangent.w));
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

        for mut x in 0..ex {
            x *= 2;
            x = if ssx { x.saturating_sub(1) } else { x.min(sx) };

            let dx = x as f32 / sx_;

            state.add_vertices([(
                p0.lerp(p1, dx),
                normal,
                tangent,
                vec2(uv.x + duv.x * dx, dv),
            )]);
        }
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
    basis: &Mat3,
    origin: &Vec3,
    start: Vec3,
    end: Vec3,
    uv: Vec2,
    dim: Vec3,
) {
    let sx = basis.x_axis * start.x;
    let sy = basis.y_axis * start.y;
    let sz = basis.z_axis * start.z;
    let ex = basis.x_axis * end.x;
    let ey = basis.y_axis * end.y;
    let ez = basis.z_axis * end.z;

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
        basis.z_axis,
        Vec4::from((basis.x_axis, 1.)),
        vec2(uv.x + dim.z, uv.y + dim.z + dim.y),
        vec2(dim.x, -dim.y),
    );
    // Back
    draw_quad(
        &mut *state,
        &[p100, p000, p110, p010],
        -basis.z_axis,
        Vec4::from((-basis.x_axis, 1.)),
        vec2(uv.x + dim.z * 2. + dim.x, uv.y + dim.z + dim.y),
        vec2(dim.x, -dim.y),
    );
    // Left
    draw_quad(
        &mut *state,
        &[p000, p001, p010, p011],
        -basis.x_axis,
        Vec4::from((basis.z_axis, -1.)),
        vec2(uv.x, uv.y + dim.z + dim.y),
        vec2(dim.z, -dim.y),
    );
    // Right
    draw_quad(
        &mut *state,
        &[p101, p100, p111, p110],
        basis.x_axis,
        Vec4::from((-basis.z_axis, -1.)),
        vec2(uv.x + dim.z + dim.x, uv.y + dim.z + dim.y),
        vec2(dim.z, -dim.y),
    );
    // Up
    draw_quad(
        &mut *state,
        &[p011, p111, p010, p110],
        basis.y_axis,
        Vec4::from((basis.x_axis, -1.)),
        vec2(uv.x + dim.z, uv.y + dim.z),
        vec2(dim.x, -dim.z),
    );
    // Down
    draw_quad(
        &mut *state,
        &[p000, p100, p001, p101],
        -basis.y_axis,
        Vec4::from((basis.x_axis, -1.)),
        vec2(uv.x + dim.z + dim.x, uv.y),
        vec2(dim.x, dim.z),
    );
}

fn draw_single_joint(
    state: &mut State,
    basis: &Mat3,
    origin: &Vec3,
    r: f32,
    Vec2 { x: u, y: v }: Vec2,
    Vec3 {
        x: dx,
        y: dy_,
        z: dz,
    }: Vec3,
    scale: f32,
    (sx, sy, sz): (usize, usize, usize),
) {
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
            basis.z_axis,
            Vec4::from((basis.x_axis, 1.)),
            vec2(u + dz, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[b10, b00, m10, m00],
            -basis.z_axis,
            Vec4::from((-basis.x_axis, 1.)),
            vec2(u + dz * 2. + dx, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[b00, b01, m00, m01],
            -basis.x_axis,
            Vec4::from((basis.z_axis, -1.)),
            vec2(u, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[b11, b10, m11, m10],
            basis.x_axis,
            Vec4::from((-basis.z_axis, -1.)),
            vec2(u + dz + dx, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
    }

    // Draw top
    {
        // Top plane
        let basis = mat3(
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
            basis.z_axis,
            Vec4::from((basis.x_axis, 1.)),
            vec2(u + dz, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[m10, m00, t10, t00],
            -basis.z_axis,
            Vec4::from((-basis.x_axis, 1.)),
            vec2(u + dz * 2. + dx, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[m00, m01, t00, t01],
            -basis.x_axis,
            Vec4::from((basis.z_axis, -1.)),
            vec2(u, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[m11, m10, t11, t10],
            basis.x_axis,
            Vec4::from((-basis.z_axis, -1.)),
            vec2(u + dz + dx, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
    }
}

fn draw_double_joint(
    state: &mut State,
    basis: &Mat3,
    origin: &Vec3,
    r: Vec3,
    Vec2 { x: u, y: v }: Vec2,
    Vec3 {
        x: dx,
        y: dy_,
        z: dz,
    }: Vec3,
    right_handed: bool,
    scale: f32,
    (sx, sy, sz): (usize, usize, usize),
) {
    // Rotate
    let (s, c) = (r.x + r.z).sin_cos();
    let basis = mat3(
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
            basis.z_axis,
            Vec4::from((basis.x_axis, 1.)),
            vec2(u + dz, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[b10, b00, m10, m00],
            -basis.z_axis,
            Vec4::from((-basis.x_axis, 1.)),
            vec2(u + dz * 2. + dx, v + dz + dy),
            vec2(dx, -dy),
            (sx, sy),
            true,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[b00, b01, m00, m01],
            -basis.x_axis,
            Vec4::from((basis.z_axis, -1.)),
            vec2(u, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[b11, b10, m11, m10],
            basis.x_axis,
            Vec4::from((-basis.z_axis, -1.)),
            vec2(u + dz + dx, v + dz + dy),
            vec2(dz, -dy),
            (sz, sy),
            true,
        );
        // Up
        draw_quad(
            &mut *state,
            &[b01, b11, b00, b10],
            basis.y_axis,
            Vec4::from((basis.x_axis, -1.)),
            vec2(u + dz, v + dz),
            vec2(dx, -dz),
        );
    }

    // Draw top
    {
        // Top plane
        let basis = basis
            * Mat3::from_axis_angle(
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
            basis.z_axis,
            Vec4::from((basis.x_axis, 1.)),
            vec2(u + dz, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Back
        draw_quad_subdiv(
            &mut *state,
            &[m10, m00, t10, t00],
            -basis.z_axis,
            Vec4::from((-basis.x_axis, 1.)),
            vec2(u + dz * 2. + dx, v + dz + dy_),
            vec2(dx, -dy),
            (sx, sy),
            false,
        );
        // Left
        draw_quad_subdiv(
            &mut *state,
            &[m00, m01, t00, t01],
            -basis.x_axis,
            Vec4::from((basis.z_axis, -1.)),
            vec2(u, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
        // Right
        draw_quad_subdiv(
            &mut *state,
            &[m11, m10, t11, t10],
            basis.x_axis,
            Vec4::from((-basis.z_axis, -1.)),
            vec2(u + dz + dx, v + dz + dy_),
            vec2(dz, -dy),
            (sz, sy),
            false,
        );
    }
}

fn draw_hand(state: &mut State, basis: &Mat3, origin: &Vec3, uv: Vec2, uv_top: Vec2, scale: f32) {
    let Vec2 { x: u, y: v } = uv;
    let bx = basis.x_axis * scale;
    let by = basis.y_axis * scale;
    let bz = basis.z_axis * scale;

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
        basis.z_axis,
        Vec4::from((basis.x_axis, 1.)),
        vec2(u + D, v + D * 2.),
        vec2(D, -D),
    );
    // Back
    draw_quad(
        &mut *state,
        &[p100, p000, p110, p010],
        -basis.z_axis,
        Vec4::from((-basis.x_axis, 1.)),
        vec2(u + D * 3., v + D * 2.),
        vec2(D, -D),
    );
    // Left
    draw_quad(
        &mut *state,
        &[p000, p001, p010, p011],
        -basis.x_axis,
        Vec4::from((basis.z_axis, -1.)),
        vec2(u, v + D * 2.),
        vec2(D, -D),
    );
    // Right
    draw_quad(
        &mut *state,
        &[p101, p100, p111, p110],
        basis.x_axis,
        Vec4::from((-basis.z_axis, -1.)),
        vec2(u + D * 2., v + D * 2.),
        vec2(D, -D),
    );
    // Down
    draw_quad(
        &mut *state,
        &[p000, p100, p001, p101],
        -basis.y_axis,
        Vec4::from((basis.x_axis, -1.)),
        vec2(uv_top.x, uv_top.y),
        vec2(D, D),
    );
}

const L2_OFF: f32 = 0.1;

fn build_mesh(input: &Angles, layer1: &mut State, layer2: &mut State) {
    let subdiv = (8, 4, 8);
    let use_layer2 = input.draw_layer2 != 0;
    let mut basis_;
    let mut basis;
    let mut origin;
    let mut r;
    let mut r_;

    // Draw body
    draw_cube(
        &mut *layer1,
        &Mat3::IDENTITY,
        &Vec3::ZERO,
        vec3(-4., -10., -2.),
        vec3(4., 2., 2.),
        vec2(16., 16.) / 64.,
        vec3(8., 12., 4.) / 64.,
    );
    if use_layer2 {
        draw_cube(
            &mut *layer2,
            &Mat3::IDENTITY,
            &Vec3::ZERO,
            vec3(-4. - L2_OFF, -10. - L2_OFF, -2. - L2_OFF),
            vec3(4. + L2_OFF, 2. + L2_OFF, 2. + L2_OFF),
            vec2(16., 32.) / 64.,
            vec3(8., 12., 4.) / 64.,
        );
    }

    // Draw head
    basis = input.head_basis;
    orthonormalize(&mut basis);
    r = euler_angle_yxz(&basis);
    basis = Mat3::from_quat(
        Quat::from_rotation_y(r.y) * Quat::from_rotation_x(r.x.clamp(-FRAC_PI_2, FRAC_PI_2)),
    );

    const HEAD_ORIG: Vec3 = vec3(0., 2., 0.);
    draw_cube(
        &mut *layer1,
        &basis,
        &HEAD_ORIG,
        vec3(-4., 0., -4.),
        vec3(4., 8., 4.),
        vec2(0., 0.) / 64.,
        vec3(8., 8., 8.) / 64.,
    );
    if use_layer2 {
        draw_cube(
            &mut *layer2,
            &basis,
            &HEAD_ORIG,
            vec3(-4. - L2_OFF, -L2_OFF, -4. - L2_OFF),
            vec3(4. + L2_OFF, 8. + L2_OFF, 4. + L2_OFF),
            vec2(32., 0.) / 64.,
            vec3(8., 8., 8.) / 64.,
        );
    }

    // Draw left arm
    basis_ = mat3(
        -input.larm_basis.y_axis,
        input.larm_basis.x_axis,
        input.larm_basis.z_axis,
    );
    orthonormalize(&mut basis_);
    r = -euler_angle_xyx(&basis_);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    basis = Mat3::from_quat(
        Quat::from_rotation_x(r.z) * Quat::from_rotation_y(r.y) * Quat::from_rotation_x(r.x),
    );
    (basis.x_axis, basis.y_axis) = (basis.y_axis, -basis.x_axis);
    basis_ = mat3(vec3(0., 2., 0.), vec3(-2., 0., 0.), vec3(0., 0., 2.));

    origin = vec3(SQRT_2 * 2. + 4., 0., 0.);
    draw_double_joint(
        &mut *layer1,
        &basis_,
        &origin,
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
            &basis_,
            &origin,
            r,
            vec2(48., 48.) / 64.,
            vec3(4., 4., 4.) / 64.,
            false,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw left elbow
    basis_ = input.lelbow_basis;
    orthonormalize(&mut basis_);
    r_ = get_angle_x(&basis_).clamp(-FRAC_PI_2, FRAC_PI_2);
    origin += basis.y_axis * ((SQRT_2 + 1.) * -2.);
    basis_ = basis * 2.;
    basis = basis * Mat3::from_rotation_x(r_);

    draw_single_joint(
        &mut *layer1,
        &basis_,
        &origin,
        r_,
        vec2(32., 52.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &basis_,
            &origin,
            r_,
            vec2(48., 52.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw left hand
    origin += basis.y_axis * -4.;

    draw_hand(
        &mut *layer1,
        &basis,
        &origin,
        vec2(32., 56.) / 64.,
        vec2(40., 48.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &basis,
            &origin,
            vec2(48., 56.) / 64.,
            vec2(56., 48.) / 64.,
            2. + L2_OFF,
        );
    }

    // Draw right arm
    basis_ = mat3(
        input.rarm_basis.y_axis,
        -input.rarm_basis.x_axis,
        input.rarm_basis.z_axis,
    );
    orthonormalize(&mut basis_);
    r = euler_angle_xyx(&basis_);
    r.y = -r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    basis = Mat3::from_quat(
        Quat::from_rotation_x(r.z) * Quat::from_rotation_y(r.y) * Quat::from_rotation_x(r.x),
    );
    (basis.x_axis, basis.y_axis) = (-basis.y_axis, basis.x_axis);
    basis_ = mat3(vec3(0., -2., 0.), vec3(2., 0., 0.), vec3(0., 0., 2.));

    origin = vec3(SQRT_2 * -2. - 4., 0., 0.);
    draw_double_joint(
        &mut *layer1,
        &basis_,
        &origin,
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
            &basis_,
            &origin,
            r,
            vec2(40., 32.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw right elbow
    basis_ = input.relbow_basis;
    orthonormalize(&mut basis_);
    r_ = get_angle_x(&basis_).clamp(-FRAC_PI_2, FRAC_PI_2);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    origin += basis.y_axis * ((SQRT_2 + 1.) * -2.);
    basis_ = basis * 2.;
    basis = basis * Mat3::from_rotation_x(r_);

    draw_single_joint(
        &mut *layer1,
        &basis_,
        &origin,
        r_,
        vec2(40., 20.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &basis_,
            &origin,
            r_,
            vec2(40., 36.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw right hand
    origin += basis.y_axis * -4.;

    draw_hand(
        &mut *layer1,
        &basis,
        &origin,
        vec2(40., 24.) / 64.,
        vec2(48., 16.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &basis,
            &origin,
            vec2(40., 40.) / 64.,
            vec2(48., 32.) / 64.,
            2. + L2_OFF,
        );
    }

    // Draw left leg
    basis_ = input.lleg_basis;
    orthonormalize(&mut basis_);
    r = euler_angle_yxy(&basis_);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    basis = Mat3::from_quat(
        Quat::from_rotation_y(-r.z) * Quat::from_rotation_x(-r.y) * Quat::from_rotation_y(-r.x),
    );
    basis_ = mat3(vec3(2., 0., 0.), vec3(0., 2., 0.), vec3(0., 0., 2.));

    origin = vec3(2., SQRT_2 * -2. - 10., 0.);
    draw_double_joint(
        &mut *layer1,
        &basis_,
        &origin,
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
            &basis_,
            &origin,
            r,
            vec2(0., 48.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw left knee
    basis_ = input.lknee_basis;
    orthonormalize(&mut basis_);
    r_ = get_angle_x(&basis_).clamp(-FRAC_PI_2, FRAC_PI_2);
    origin += basis.y_axis * ((SQRT_2 + 1.) * -2.);
    basis_ = basis * 2.;
    basis = basis * Mat3::from_rotation_x(r_);

    draw_single_joint(
        &mut *layer1,
        &basis_,
        &origin,
        r_,
        vec2(16., 52.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &basis_,
            &origin,
            r_,
            vec2(0., 52.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw left foot
    origin += basis.y_axis * -4.;

    draw_hand(
        &mut *layer1,
        &basis,
        &origin,
        vec2(16., 56.) / 64.,
        vec2(24., 48.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &basis,
            &origin,
            vec2(0., 56.) / 64.,
            vec2(8., 48.) / 64.,
            2. + L2_OFF,
        );
    }

    // Draw right leg
    basis_ = input.rleg_basis;
    orthonormalize(&mut basis_);
    r = euler_angle_yxy(&basis_);
    r.y = r.y.clamp(-FRAC_PI_2, FRAC_PI_2);
    basis = Mat3::from_quat(
        Quat::from_rotation_y(-r.z) * Quat::from_rotation_x(-r.y) * Quat::from_rotation_y(-r.x),
    );
    basis_ = mat3(vec3(2., 0., 0.), vec3(0., 2., 0.), vec3(0., 0., 2.));

    origin = vec3(-2., SQRT_2 * -2. - 10., 0.);
    draw_double_joint(
        &mut *layer1,
        &basis_,
        &origin,
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
            &basis_,
            &origin,
            r,
            vec2(0., 32.) / 64.,
            vec3(4., 4., 4.) / 64.,
            true,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw right knee
    basis_ = input.rknee_basis;
    orthonormalize(&mut basis_);
    r_ = get_angle_x(&basis_).clamp(-FRAC_PI_2, FRAC_PI_2);
    origin += basis.y_axis * ((SQRT_2 + 1.) * -2.);
    basis_ = basis * 2.;
    basis = basis * Mat3::from_rotation_x(r_);

    draw_single_joint(
        &mut *layer1,
        &basis_,
        &origin,
        r_,
        vec2(0., 20.) / 64.,
        vec3(4., 4., 4.) / 64.,
        1.,
        subdiv,
    );
    if use_layer2 {
        draw_single_joint(
            &mut *layer2,
            &basis_,
            &origin,
            r_,
            vec2(0., 36.) / 64.,
            vec3(4., 4., 4.) / 64.,
            1. + L2_OFF / 2.,
            subdiv,
        );
    }

    // Draw right foot
    origin += basis.y_axis * -4.;

    draw_hand(
        &mut *layer1,
        &basis,
        &origin,
        vec2(0., 24.) / 64.,
        vec2(8., 16.) / 64.,
        2.,
    );
    if use_layer2 {
        draw_hand(
            &mut *layer2,
            &basis,
            &origin,
            vec2(0., 40.) / 64.,
            vec2(8., 32.) / 64.,
            2. + L2_OFF,
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
                        let (xn, yn) = octahedron_encode(*n);
                        let (xt, yt) = octahedron_tangent_encode(*t);
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
