@tool
extends Node3D

const PI_2 := PI / 2
const SQRT_2 := sqrt(2)
const SQRT_1_2 := sqrt(0.5)

const MASK_UP    := 0b000001
const MASK_DOWN  := 0b000010
const MASK_LEFT  := 0b000100
const MASK_RIGHT := 0b001000
const MASK_FRONT := 0b010000
const MASK_BACK  := 0b100000

@export var material: Material:
	set(v):
		material = v
		queue_rerender = true
@export var material_layer2: Material:
	set(v):
		material_layer2 = v
		queue_rerender = true
@export_range(0, 1, 0.01, "or_greater") var layer2_offset: float = 0.1:
	set(v):
		layer2_offset = v
		queue_rerender = true

var queue_rerender := true

func _get_euler_xyx(b: Basis) -> Vector3:
	var c2 := b[0][0]
	var temp: float = abs(c2)
	if temp >= 1.0 or is_zero_approx(1.0 - temp):
		if temp >= 0:
			return Vector3(
				atan2(b[2][1], b[1][1]),
				0,
				0,
			)
		else:
			return Vector3(
				atan2(-b[2][1], b[1][1]),
				PI,
				0,
			)
	else:
		return Vector3(
			atan2(b[1][0], -b[2][0]),
			acos(c2),
			atan2(b[0][1], b[0][2]),
		)

func _get_euler_yxy(b: Basis) -> Vector3:
	var c2 := b[1][1]
	var temp: float = abs(c2)
	if temp >= 1.0 or is_zero_approx(1.0 - temp):
		if temp >= 0:
			return Vector3(
				atan2(b[0][2], b[0][0]),
				0,
				0,
			)
		else:
			return Vector3(
				atan2(-b[0][2], b[0][0]),
				PI,
				0,
			)
	else:
		return Vector3(
			atan2(b[0][1], b[2][1]),
			acos(c2),
			atan2(b[1][0], -b[1][2]),
		)

func _draw_quad(
	s: Array,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	p4: Vector3,
	uv: Vector2,
	duv: Vector2,
):
	var d1 := p4 - p1
	var d2 := p3 - p2
	var n := d1.cross(d2).normalized()

	var va: Array = s[Mesh.ARRAY_VERTEX]
	var na: Array = s[Mesh.ARRAY_NORMAL]
	var uva: Array = s[Mesh.ARRAY_TEX_UV]
	var ia: Array = s[Mesh.ARRAY_INDEX]
	var i := len(va)

	va.append_array([p1, p2, p3, p4])
	na.append_array([n, n, n, n])
	uva.append_array([uv, uv + Vector2(duv.x, 0), uv + Vector2(0, duv.y), uv + duv])
	if d1.length_squared() <= d2.length_squared():
		ia.append_array([i, i + 3, i + 1, i, i + 2, i + 3])
	else:
		ia.append_array([i, i + 2, i + 1, i + 1, i + 2, i + 3])

func _draw_cube(
	s: Array,
	p000: Vector3,
	p001: Vector3,
	p010: Vector3,
	p011: Vector3,
	p100: Vector3,
	p101: Vector3,
	p110: Vector3,
	p111: Vector3,
	uv: Vector2,
	dim: Vector3,
	mask: int = 0b111111,
):
	if mask & MASK_FRONT:
		_draw_quad(s, p001, p101, p011, p111, uv + Vector2(dim.z, dim.z + dim.y), Vector2(dim.x, -dim.y))
	if mask & MASK_BACK:
		_draw_quad(s, p100, p000, p110, p010, uv + Vector2(dim.z * 2 + dim.x, dim.z + dim.y), Vector2(dim.x, -dim.y))
	if mask & MASK_RIGHT:
		_draw_quad(s, p000, p001, p010, p011, uv + Vector2(0, dim.z + dim.y), Vector2(dim.z, -dim.y))
	if mask & MASK_LEFT:
		_draw_quad(s, p101, p100, p111, p110, uv + Vector2(dim.z + dim.x, dim.z + dim.y), Vector2(dim.z, -dim.y))
	if mask & MASK_UP:
		_draw_quad(s, p011, p111, p010, p110, uv + Vector2(dim.z, dim.z), Vector2(dim.x, -dim.z))
	if mask & MASK_DOWN:
		_draw_quad(s, p000, p100, p001, p101, uv + Vector2(dim.z + dim.x, 0), Vector2(dim.x, dim.z))

func _draw_double_joint(
	s: Array,
	t: Transform3D,
	r: Vector3,
	uv: Vector2,
	dim: Vector3,
	right_handed: bool,
	scale: float = 1,
):
	t = t * Transform3D(Basis(Vector3(0, -1, 0), r.x + r.z), Vector3.ZERO)
	var p010 := t * Vector3(-scale, SQRT_2 * scale, -scale)
	var p011 := t * Vector3(-scale, SQRT_2 * scale, scale)
	var p110 := t * Vector3(scale, SQRT_2 * scale, -scale)
	var p111 := t * Vector3(scale, SQRT_2 * scale, scale)
	_draw_quad(s, p011, p111, p010, p110, uv + Vector2(dim.z, dim.z), Vector2(dim.x, -dim.z))

	var sx := sin(r.x)
	var cx := cos(r.x)
	var ty2 := tan(r.y * 0.5) * scale
	if not right_handed:
		ty2 = -ty2

	var p000 := t * Vector3(-scale, (-sx - cx) * ty2, -scale)
	var p001 := t * Vector3(-scale, (-sx + cx) * ty2, scale)
	var p100 := t * Vector3(scale, (sx - cx) * ty2, -scale)
	var p101 := t * Vector3(scale, (sx + cx) * ty2, scale)

	var dim2 := Vector3(dim.x, dim.y * 0.5, dim.z)
	_draw_cube(
		s,
		p000,
		p001,
		p010,
		p011,
		p100,
		p101,
		p110,
		p111,
		uv,
		dim2,
		0b111100,
	)

	t = t * Transform3D(Basis(Vector3(-cx, 0, sx) if right_handed else Vector3(cx, 0, -sx), r.y), Vector3.ZERO)
	p010 = t * Vector3(-scale, -SQRT_2, -scale)
	p011 = t * Vector3(-scale, -SQRT_2, scale)
	p110 = t * Vector3(scale, -SQRT_2, -scale)
	p111 = t * Vector3(scale, -SQRT_2, scale)
	_draw_cube(
		s,
		p010,
		p011,
		p000,
		p001,
		p110,
		p111,
		p100,
		p101,
		Vector2(uv.x, uv.y + dim2.y),
		dim2,
		0b111100,
	)

func _draw_single_joint(
	s: Array,
	t: Transform3D,
	r: float,
	uv: Vector2,
	dim: Vector3,
	scale: float = 1,
):
	var p010 := t * Vector3(-scale, 1, -scale)
	var p011 := t * Vector3(-scale, 1, scale)
	var p110 := t * Vector3(scale, 1, -scale)
	var p111 := t * Vector3(scale, 1, scale)

	r = clampf(r, -PI_2, PI_2)
	var tz2 := tan(r * 0.5) * scale

	var p000 := t * Vector3(-scale, tz2, -scale)
	var p001 := t * Vector3(-scale, -tz2, scale)
	var p100 := t * Vector3(scale, tz2, -scale)
	var p101 := t * Vector3(scale, -tz2, scale)

	var dim2 := Vector3(dim.x, dim.y * 0.5, dim.z)
	_draw_cube(
		s,
		p000,
		p001,
		p010,
		p011,
		p100,
		p101,
		p110,
		p111,
		uv,
		dim2,
		0b111100,
	)

	t = t * Transform3D(Basis(Vector3(1, 0, 0), r), Vector3.ZERO)
	p010 = t * Vector3(-scale, -1, -scale)
	p011 = t * Vector3(-scale, -1, scale)
	p110 = t * Vector3(scale, -1, -scale)
	p111 = t * Vector3(scale, -1, scale)
	_draw_cube(
		s,
		p010,
		p011,
		p000,
		p001,
		p110,
		p111,
		p100,
		p101,
		Vector2(uv.x, uv.y + dim2.y),
		dim2,
		0b111100,
	)

func rerender():
	var mesh := $Mesh
	var skeleton: Skeleton3D = mesh.get_node(mesh.skeleton)
	var skin: Skin = mesh.skin
	if skeleton != null and skin == null:
		skin = skeleton.create_skin_from_rest_transforms()
		mesh.skin = skin

	var m: ArrayMesh = mesh.mesh
	m.clear_surfaces()

	var s := []
	s.resize(Mesh.ARRAY_MAX)
	s[Mesh.ARRAY_VERTEX] = []
	s[Mesh.ARRAY_NORMAL] = []
	s[Mesh.ARRAY_TEX_UV] = []
	s[Mesh.ARRAY_INDEX] = []

	var draw_l2 := material_layer2 != null
	var s2 := []
	s2.resize(Mesh.ARRAY_MAX)
	s2[Mesh.ARRAY_VERTEX] = []
	s2[Mesh.ARRAY_NORMAL] = []
	s2[Mesh.ARRAY_TEX_UV] = []
	s2[Mesh.ARRAY_INDEX] = []

	# Draw Head
	var ix := skeleton.find_bone("head")
	var t := skeleton.get_bone_global_pose(ix)
	var r := t.basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	t.basis = Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), clampf(r.x, -PI_2, PI_2)) * Basis.from_scale(Vector3(4, 8, 4))
	var p000 := t * Vector3(-1, 0, -1)
	var p001 := t * Vector3(-1, 0, 1)
	var p100 := t * Vector3(1, 0, -1)
	var p101 := t * Vector3(1, 0, 1)
	var p010 := t * Vector3(-1, 1, -1)
	var p011 := t * Vector3(-1, 1, 1)
	var p110 := t * Vector3(1, 1, -1)
	var p111 := t * Vector3(1, 1, 1)
	_draw_cube(
		s,
		p000,
		p001,
		p010,
		p011,
		p100,
		p101,
		p110,
		p111,
		Vector2(0, 0),
		Vector3(8, 8, 8) / 64,
	)
	if draw_l2:
		_draw_cube(
			s2,
			t * Vector3(-1 - layer2_offset / 4, -layer2_offset / 8, -1 - layer2_offset / 4),
			t * Vector3(-1 - layer2_offset / 4, -layer2_offset / 8, 1 + layer2_offset / 4),
			t * Vector3(-1 - layer2_offset / 4, 1 + layer2_offset / 8, -1 - layer2_offset / 4),
			t * Vector3(-1 - layer2_offset / 4, 1 + layer2_offset / 8, 1 + layer2_offset / 4),
			t * Vector3(1 + layer2_offset / 4, -layer2_offset / 8, -1 - layer2_offset / 4),
			t * Vector3(1 + layer2_offset / 4, -layer2_offset / 8, 1 + layer2_offset / 4),
			t * Vector3(1 + layer2_offset / 4, 1 + layer2_offset / 8, -1 - layer2_offset / 4),
			t * Vector3(1 + layer2_offset / 4, 1 + layer2_offset / 8, 1 + layer2_offset / 4),
			Vector2(32, 0) / 64,
			Vector3(8, 8, 8) / 64,
		)

	# Draw Body
	ix = skeleton.find_bone("body")
	t = skeleton.get_bone_global_pose(ix)
	_draw_cube(
		s,
		t * Vector3(-4, -10, -2),
		t * Vector3(-4, -10, 2),
		t * Vector3(-4, 2, -2),
		t * Vector3(-4, 2, 2),
		t * Vector3(4, -10, -2),
		t * Vector3(4, -10, 2),
		t * Vector3(4, 2, -2),
		t * Vector3(4, 2, 2),
		Vector2(16, 16) / 64,
		Vector3(8, 12, 4) / 64,
	)
	if draw_l2:
		_draw_cube(
			s,
			t * Vector3(-4 - layer2_offset, -10 - layer2_offset, -2 - layer2_offset),
			t * Vector3(-4 - layer2_offset, -10 - layer2_offset, 2 + layer2_offset),
			t * Vector3(-4 - layer2_offset, 2 + layer2_offset, -2 - layer2_offset),
			t * Vector3(-4 - layer2_offset, 2 + layer2_offset, 2 + layer2_offset),
			t * Vector3(4 + layer2_offset, -10 - layer2_offset, -2 - layer2_offset),
			t * Vector3(4 + layer2_offset, -10 - layer2_offset, 2 + layer2_offset),
			t * Vector3(4 + layer2_offset, 2 + layer2_offset, -2 - layer2_offset),
			t * Vector3(4 + layer2_offset, 2 + layer2_offset, 2 + layer2_offset),
			Vector2(16, 32) / 64,
			Vector3(8, 12, 4) / 64,
		)

	# Draw Left Arm
	ix = skeleton.find_bone("left_arm")
	t = skeleton.get_bone_global_pose(ix)
	r = -_get_euler_xyx((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	var t_ := Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(32, 48) / 64, Vector3(4, 4, 4) / 64, false)
	if draw_l2:
		_draw_double_joint(s2, t_, r, Vector2(48, 48) / 64, Vector3(4, 4, 4) / 64, false, 1 + layer2_offset / 2)
	t.basis = Basis(Vector3(1, 0, 0), r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), r.x) * t.basis

	# Draw Left Elbow
	ix = skeleton.find_bone("left_elbow")
	t_ = skeleton.get_bone_pose(ix)
	var r_ := clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(32, 52) / 64, Vector3(4, 4, 4) / 64)
	if draw_l2:
		_draw_single_joint(s2, t_, r_, Vector2(48, 52) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Left Hand
	ix = skeleton.find_bone("left_hand")
	t_ = skeleton.get_bone_pose(ix)
	t_.basis = t.basis.scaled(Vector3(2, 2, 2))
	t_.origin = t * t_.origin
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		s,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(32, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(40, 48) / 64, Vector2(4, 4) / 64)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			s2,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			Vector2(48, 56) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(s2, p000, p100, p001, p101, Vector2(56, 48) / 64, Vector2(4, 4) / 64)

	# Draw Right Arm
	ix = skeleton.find_bone("right_arm")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_xyx((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = -clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(40, 16) / 64, Vector3(4, 4, 4) / 64, true)
	if draw_l2:
		_draw_double_joint(s2, t_, r, Vector2(40, 32) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2)
	t.basis = Basis(Vector3(1, 0, 0), -r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), -r.x) * t.basis

	# Draw Right Elbow
	ix = skeleton.find_bone("right_elbow")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(40, 20) / 64, Vector3(4, 4, 4) / 64)
	if draw_l2:
		_draw_single_joint(s2, t_, r_, Vector2(40, 36) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Right Hand
	ix = skeleton.find_bone("right_hand")
	t_ = skeleton.get_bone_pose(ix)
	t_.basis = t.basis.scaled(Vector3(2, 2, 2))
	t_.origin = t * t_.origin
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		s,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(40, 24) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(48, 16) / 64, Vector2(4, 4) / 64)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			s2,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			Vector2(40, 40) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(s2, p000, p100, p001, p101, Vector2(48, 32) / 64, Vector2(4, 4) / 64)

	# Draw Left Leg
	ix = skeleton.find_bone("left_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(16, 48) / 64, Vector3(4, 4, 4) / 64, true)
	if draw_l2:
		_draw_double_joint(s2, t_, r, Vector2(0, 48) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Left Knee
	ix = skeleton.find_bone("left_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(16, 52) / 64, Vector3(4, 4, 4) / 64)
	if draw_l2:
		_draw_single_joint(s2, t_, r_, Vector2(0, 52) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Left Foot
	ix = skeleton.find_bone("left_foot")
	t_ = skeleton.get_bone_pose(ix)
	t_.basis = t.basis.scaled(Vector3(2, 2, 2))
	t_.origin = t * t_.origin
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		s,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(16, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(24, 48) / 64, Vector2(4, 4) / 64)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			s2,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			Vector2(0, 56) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(s2, p000, p100, p001, p101, Vector2(8, 48) / 64, Vector2(4, 4) / 64)

	# Draw Right Leg
	ix = skeleton.find_bone("right_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(0, 16) / 64, Vector3(4, 4, 4) / 64, true)
	if draw_l2:
		_draw_double_joint(s2, t_, r, Vector2(0, 32) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Right Knee
	ix = skeleton.find_bone("right_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(0, 20) / 64, Vector3(4, 4, 4) / 64)
	if draw_l2:
		_draw_single_joint(s2, t_, r_, Vector2(0, 36) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Right Foot
	ix = skeleton.find_bone("right_foot")
	t_ = skeleton.get_bone_pose(ix)
	t_.basis = t.basis.scaled(Vector3(2, 2, 2))
	t_.origin = t * t_.origin
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		s,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(0, 24) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(8, 16) / 64, Vector2(4, 4) / 64)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			s2,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			Vector2(0, 40) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(s2, p000, p100, p001, p101, Vector2(8, 32) / 64, Vector2(4, 4) / 64)

	s[Mesh.ARRAY_VERTEX] = PackedVector3Array(s[Mesh.ARRAY_VERTEX])
	s[Mesh.ARRAY_NORMAL] = PackedVector3Array(s[Mesh.ARRAY_NORMAL])
	s[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s[Mesh.ARRAY_TEX_UV])
	s[Mesh.ARRAY_INDEX] = PackedInt32Array(s[Mesh.ARRAY_INDEX])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s)
	m.surface_set_material(0, material)

	if draw_l2:
		s2[Mesh.ARRAY_VERTEX] = PackedVector3Array(s2[Mesh.ARRAY_VERTEX])
		s2[Mesh.ARRAY_NORMAL] = PackedVector3Array(s2[Mesh.ARRAY_NORMAL])
		s2[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s2[Mesh.ARRAY_TEX_UV])
		s2[Mesh.ARRAY_INDEX] = PackedInt32Array(s2[Mesh.ARRAY_INDEX])
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s2)
		m.surface_set_material(1, material_layer2)

func _enter_tree():
	var c := Callable(self, "_update_pose")
	var skeleton := $Skeleton
	if not skeleton.is_connected("pose_updated", c):
		skeleton.connect("pose_updated", c)

func _process(_delta):
	if queue_rerender:
		queue_rerender = false
		rerender()

func _update_pose():
	queue_rerender = true
