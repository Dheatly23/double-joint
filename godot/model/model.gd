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
):
	t = t * Transform3D(Basis(Vector3(0, -1, 0), r.x + r.z), Vector3.ZERO)
	var p010 := t * Vector3(-1, SQRT_2, -1)
	var p011 := t * Vector3(-1, SQRT_2, 1)
	var p110 := t * Vector3(1, SQRT_2, -1)
	var p111 := t * Vector3(1, SQRT_2, 1)
	_draw_quad(s, p011, p111, p010, p110, uv + Vector2(dim.z, dim.z), Vector2(dim.x, -dim.z))

	var sx := sin(r.x)
	var cx := cos(r.x)
	var ty2 := tan(r.y * 0.5)
	if not right_handed:
		ty2 = -ty2

	var p000 := t * Vector3(-1, (-sx - cx) * ty2, -1)
	var p001 := t * Vector3(-1, (-sx + cx) * ty2, 1)
	var p100 := t * Vector3(1, (sx - cx) * ty2, -1)
	var p101 := t * Vector3(1, (sx + cx) * ty2, 1)

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
	p010 = t * Vector3(-1, -SQRT_2, -1)
	p011 = t * Vector3(-1, -SQRT_2, 1)
	p110 = t * Vector3(1, -SQRT_2, -1)
	p111 = t * Vector3(1, -SQRT_2, 1)
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
):
	var p010 := t * Vector3(-1, 1, -1)
	var p011 := t * Vector3(-1, 1, 1)
	var p110 := t * Vector3(1, 1, -1)
	var p111 := t * Vector3(1, 1, 1)

	r = clampf(r, -PI_2, PI_2)
	var tz2 := tan(r * 0.5)

	var p000 := t * Vector3(-1, tz2, -1)
	var p001 := t * Vector3(-1, -tz2, 1)
	var p100 := t * Vector3(1, tz2, -1)
	var p101 := t * Vector3(1, -tz2, 1)

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
	p010 = t * Vector3(-1, -1, -1)
	p011 = t * Vector3(-1, -1, 1)
	p110 = t * Vector3(1, -1, -1)
	p111 = t * Vector3(1, -1, 1)
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

	# Draw Body
	_draw_cube(
		s,
		Vector3(-4, -10, -2),
		Vector3(-4, -10, 2),
		Vector3(-4, 2, -2),
		Vector3(-4, 2, 2),
		Vector3(4, -10, -2),
		Vector3(4, -10, 2),
		Vector3(4, 2, -2),
		Vector3(4, 2, 2),
		Vector2(16, 16) / 64,
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
	t.basis = Basis(Vector3(1, 0, 0), r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), r.x) * t.basis

	# Draw Left Elbow
	ix = skeleton.find_bone("left_elbow")
	t_ = skeleton.get_bone_pose(ix)
	var r_ := clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(32, 52) / 64, Vector3(4, 4, 4) / 64)
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
		t_ * Vector3(-1, -1, -1),
		t_ * Vector3(-1, -1, 1),
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		t_ * Vector3(1, -1, -1),
		t_ * Vector3(1, -1, 1),
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(32, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(40, 48) / 64, Vector2(4, 4) / 64)

	# Draw Right Arm
	ix = skeleton.find_bone("right_arm")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_xyx((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = -clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(40, 16) / 64, Vector3(4, 4, 4) / 64, true)
	t.basis = Basis(Vector3(1, 0, 0), -r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), -r.x) * t.basis

	# Draw Right Elbow
	ix = skeleton.find_bone("right_elbow")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(40, 20) / 64, Vector3(4, 4, 4) / 64)
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
		t_ * Vector3(-1, -1, -1),
		t_ * Vector3(-1, -1, 1),
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		t_ * Vector3(1, -1, -1),
		t_ * Vector3(1, -1, 1),
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(32, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(48, 16) / 64, Vector2(4, 4) / 64)

	# Draw Left Leg
	ix = skeleton.find_bone("left_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(16, 48) / 64, Vector3(4, 4, 4) / 64, true)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Left Knee
	ix = skeleton.find_bone("left_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(16, 52) / 64, Vector3(4, 4, 4) / 64)
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
		t_ * Vector3(-1, -1, -1),
		t_ * Vector3(-1, -1, 1),
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		t_ * Vector3(1, -1, -1),
		t_ * Vector3(1, -1, 1),
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(16, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(24, 48) / 64, Vector2(4, 4) / 64)

	# Draw Right Leg
	ix = skeleton.find_bone("right_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(s, t_, r, Vector2(0, 16) / 64, Vector3(4, 4, 4) / 64, true)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Right Knee
	ix = skeleton.find_bone("right_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(s, t_, r_, Vector2(0, 20) / 64, Vector3(4, 4, 4) / 64)
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
		t_ * Vector3(-1, -1, -1),
		t_ * Vector3(-1, -1, 1),
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		t_ * Vector3(1, -1, -1),
		t_ * Vector3(1, -1, 1),
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		Vector2(0, 24) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(s, p000, p100, p001, p101, Vector2(8, 16) / 64, Vector2(4, 4) / 64)

	s[Mesh.ARRAY_VERTEX] = PackedVector3Array(s[Mesh.ARRAY_VERTEX])
	s[Mesh.ARRAY_NORMAL] = PackedVector3Array(s[Mesh.ARRAY_NORMAL])
	s[Mesh.ARRAY_TEX_UV] = PackedVector2Array(s[Mesh.ARRAY_TEX_UV])
	s[Mesh.ARRAY_INDEX] = PackedInt32Array(s[Mesh.ARRAY_INDEX])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s)
	m.surface_set_material(0, material)

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
