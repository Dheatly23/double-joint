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
var surfaces: Array[Array] = [
	[SurfaceTool.new(), 0],
	[SurfaceTool.new(), 0],
]

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
	s: int,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	p4: Vector3,
	n: Vector3,
	t: Plane,
	uv: Vector2,
	duv: Vector2,
	subdiv: Vector2i = Vector2i.ONE,
	shsubdiv: bool = false,
):
	n = n.normalized()
	t = t.normalized()
	var d1 := p4 - p1
	var d2 := p3 - p2

	var a := surfaces[s]
	var st: SurfaceTool = a[0]
	var i: int = a[1]

	var si := Vector2.ONE / Vector2(subdiv)
	for y in range(0, subdiv.y + 2, 2):
		if shsubdiv:
			y -= subdiv.y & 1
		y = clampi(y, 0, subdiv.y)
		for x in range(0, subdiv.x + 2, 2):
			if shsubdiv:
				x -= subdiv.x & 1
			x = clampi(x, 0, subdiv.x)
			var dv := Vector2(x, y) * si
			var iv := Vector2(subdiv - Vector2i(x, y)) * si
			st.set_normal(n)
			st.set_tangent(t)
			st.set_uv(uv + duv * dv)
			st.add_vertex(
				p1 * iv.x * iv.y +
				p2 * dv.x * iv.y +
				p3 * iv.x * dv.y +
				p4 * dv.x * dv.y
			)

	var i_: Vector2i = (subdiv + Vector2i(3, 3)) / 2
	var diag := d1.length_squared() <= d2.length_squared()
	for y in range(i_.y - 1):
		for x in range(i_.x - 1):
			var j := i + x + y * i_.x
			if diag:
				st.add_index(j)
				st.add_index(j + i_.x + 1)
				st.add_index(j + 1)
				st.add_index(j)
				st.add_index(j + i_.x)
				st.add_index(j + i_.x + 1)
			else:
				st.add_index(j)
				st.add_index(j + i_.x)
				st.add_index(j + 1)
				st.add_index(j + 1)
				st.add_index(j + i_.x)
				st.add_index(j + i_.x + 1)

	a[1] = i + i_.x * i_.y

func _draw_cube(
	s: int,
	p000: Vector3,
	p001: Vector3,
	p010: Vector3,
	p011: Vector3,
	p100: Vector3,
	p101: Vector3,
	p110: Vector3,
	p111: Vector3,
	n: Basis,
	uv: Vector2,
	dim: Vector3,
	mask: int = 0b111111,
	subdiv: Vector3i = Vector3i.ONE,
	shsubdiv: bool = false,
):
	if mask & MASK_FRONT:
		_draw_quad(
			s,
			p001,
			p101,
			p011,
			p111,
			n.z,
			Plane(n.x, 1),
			uv + Vector2(dim.z, dim.z + dim.y),
			Vector2(dim.x, -dim.y),
			Vector2i(subdiv.x, subdiv.y),
			shsubdiv,
		)
	if mask & MASK_BACK:
		_draw_quad(
			s,
			p100,
			p000,
			p110,
			p010,
			-n.z,
			Plane(-n.x, 1),
			uv + Vector2(dim.z * 2 + dim.x, dim.z + dim.y),
			Vector2(dim.x, -dim.y),
			Vector2i(subdiv.x, subdiv.y),
			shsubdiv,
		)
	if mask & MASK_RIGHT:
		_draw_quad(
			s,
			p000,
			p001,
			p010,
			p011,
			-n.x,
			Plane(n.z, -1),
			uv + Vector2(0, dim.z + dim.y),
			Vector2(dim.z, -dim.y),
			Vector2i(subdiv.z, subdiv.y),
			shsubdiv,
		)
	if mask & MASK_LEFT:
		_draw_quad(
			s,
			p101,
			p100,
			p111,
			p110,
			n.x,
			Plane(-n.z, -1),
			uv + Vector2(dim.z + dim.x, dim.z + dim.y),
			Vector2(dim.z, -dim.y),
			Vector2i(subdiv.z, subdiv.y),
			shsubdiv,
		)
	if mask & MASK_UP:
		_draw_quad(
			s,
			p011,
			p111,
			p010,
			p110,
			n.y,
			Plane(n.x, -1),
			uv + Vector2(dim.z, dim.z),
			Vector2(dim.x, -dim.z),
			Vector2i(subdiv.x, subdiv.z),
			shsubdiv,
		)
	if mask & MASK_DOWN:
		_draw_quad(
			s,
			p000,
			p100,
			p001,
			p101,
			-n.y,
			Plane(n.x, -1),
			uv + Vector2(dim.z + dim.x, 0),
			Vector2(dim.x, dim.z),
			Vector2i(subdiv.x, subdiv.z),
			shsubdiv,
		)

func _draw_double_joint(
	s: int,
	t: Transform3D,
	r: Vector3,
	uv: Vector2,
	dim: Vector3,
	right_handed: bool,
	scale: float = 1,
	subdiv: Vector3i = Vector3i.ONE,
):
	t = t * Transform3D(Basis(Vector3(0, -1, 0), r.x + r.z), Vector3.ZERO)
	var p010 := t * Vector3(-scale, SQRT_2 * scale, -scale)
	var p011 := t * Vector3(-scale, SQRT_2 * scale, scale)
	var p110 := t * Vector3(scale, SQRT_2 * scale, -scale)
	var p111 := t * Vector3(scale, SQRT_2 * scale, scale)
	_draw_quad(
		s,
		p011,
		p111,
		p010,
		p110,
		t.basis.y,
		Plane(t.basis.x, -1),
		uv + Vector2(dim.z, dim.z),
		Vector2(dim.x, -dim.z),
	)

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
		t.basis,
		uv,
		dim2,
		0b111100,
		subdiv,
		true,
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
		t.basis,
		Vector2(uv.x, uv.y + dim2.y),
		dim2,
		0b111100,
		subdiv,
	)

func _draw_single_joint(
	s: int,
	t: Transform3D,
	r: float,
	uv: Vector2,
	dim: Vector3,
	scale: float = 1,
	subdiv: Vector3i = Vector3i.ONE,
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
		t.basis,
		uv,
		dim2,
		0b111100,
		subdiv,
		true,
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
		t.basis,
		Vector2(uv.x, uv.y + dim2.y),
		dim2,
		0b111100,
		subdiv,
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

	var draw_l2 := material_layer2 != null
	for s in surfaces:
		s[0].begin(Mesh.PRIMITIVE_TRIANGLES)
		s[1] = 0

	var subdiv := Vector3i(8, 4, 8)

	# Draw Head
	var ix := skeleton.find_bone("head")
	var t := skeleton.get_bone_global_pose(ix)
	var r := t.basis.orthonormalized().get_euler(EULER_ORDER_YXZ)
	t.basis = Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), clampf(r.x, -PI_2, PI_2))
	var p000 := t * Vector3(-4, 0, -4)
	var p001 := t * Vector3(-4, 0, 4)
	var p100 := t * Vector3(4, 0, -4)
	var p101 := t * Vector3(4, 0, 4)
	var p010 := t * Vector3(-4, 8, -4)
	var p011 := t * Vector3(-4, 8, 4)
	var p110 := t * Vector3(4, 8, -4)
	var p111 := t * Vector3(4, 8, 4)
	_draw_cube(
		0,
		p000,
		p001,
		p010,
		p011,
		p100,
		p101,
		p110,
		p111,
		t.basis,
		Vector2(0, 0),
		Vector3(8, 8, 8) / 64,
	)
	if draw_l2:
		_draw_cube(
			1,
			t * Vector3(-4 - layer2_offset, -layer2_offset, -4 - layer2_offset),
			t * Vector3(-4 - layer2_offset, -layer2_offset, 4 + layer2_offset),
			t * Vector3(-4 - layer2_offset, 8 + layer2_offset, -4 - layer2_offset),
			t * Vector3(-4 - layer2_offset, 8 + layer2_offset, 4 + layer2_offset),
			t * Vector3(4 + layer2_offset, -layer2_offset, -4 - layer2_offset),
			t * Vector3(4 + layer2_offset, -layer2_offset, 4 + layer2_offset),
			t * Vector3(4 + layer2_offset, 8 + layer2_offset, -4 - layer2_offset),
			t * Vector3(4 + layer2_offset, 8 + layer2_offset, 4 + layer2_offset),
			t.basis,
			Vector2(32, 0) / 64,
			Vector3(8, 8, 8) / 64,
		)

	# Draw Body
	ix = skeleton.find_bone("body")
	t = skeleton.get_bone_global_pose(ix)
	_draw_cube(
		0,
		t * Vector3(-4, -10, -2),
		t * Vector3(-4, -10, 2),
		t * Vector3(-4, 2, -2),
		t * Vector3(-4, 2, 2),
		t * Vector3(4, -10, -2),
		t * Vector3(4, -10, 2),
		t * Vector3(4, 2, -2),
		t * Vector3(4, 2, 2),
		t.basis,
		Vector2(16, 16) / 64,
		Vector3(8, 12, 4) / 64,
	)
	if draw_l2:
		_draw_cube(
			1,
			t * Vector3(-4 - layer2_offset, -10 - layer2_offset, -2 - layer2_offset),
			t * Vector3(-4 - layer2_offset, -10 - layer2_offset, 2 + layer2_offset),
			t * Vector3(-4 - layer2_offset, 2 + layer2_offset, -2 - layer2_offset),
			t * Vector3(-4 - layer2_offset, 2 + layer2_offset, 2 + layer2_offset),
			t * Vector3(4 + layer2_offset, -10 - layer2_offset, -2 - layer2_offset),
			t * Vector3(4 + layer2_offset, -10 - layer2_offset, 2 + layer2_offset),
			t * Vector3(4 + layer2_offset, 2 + layer2_offset, -2 - layer2_offset),
			t * Vector3(4 + layer2_offset, 2 + layer2_offset, 2 + layer2_offset),
			t.basis,
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
	_draw_double_joint(0, t_, r, Vector2(32, 48) / 64, Vector3(4, 4, 4) / 64, false, 1, subdiv)
	if draw_l2:
		_draw_double_joint(1, t_, r, Vector2(48, 48) / 64, Vector3(4, 4, 4) / 64, false, 1 + layer2_offset / 2, subdiv)
	t.basis = Basis(Vector3(1, 0, 0), r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), r.x) * t.basis

	# Draw Left Elbow
	ix = skeleton.find_bone("left_elbow")
	t_ = skeleton.get_bone_pose(ix)
	var r_ := clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(0, t_, r_, Vector2(32, 52) / 64, Vector3(4, 4, 4) / 64, 1, subdiv)
	if draw_l2:
		_draw_single_joint(1, t_, r_, Vector2(48, 52) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2, subdiv)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Left Hand
	ix = skeleton.find_bone("left_hand")
	t_ = skeleton.get_bone_pose(ix)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		0,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		t.basis,
		Vector2(32, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(
		0,
		p000,
		p100,
		p001,
		p101,
		-t.basis.y,
		Plane(t.basis.x, -1),
		Vector2(40, 48) / 64,
		Vector2(4, 4) / 64,
	)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			1,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			t.basis,
			Vector2(48, 56) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(
			1,
			p000,
			p100,
			p001,
			p101,
			-t.basis.y,
			Plane(t.basis.x, -1),
			Vector2(56, 48) / 64,
			Vector2(4, 4) / 64,
		)

	# Draw Right Arm
	ix = skeleton.find_bone("right_arm")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_xyx((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = -clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(0, t_, r, Vector2(40, 16) / 64, Vector3(4, 4, 4) / 64, true, 1, subdiv)
	if draw_l2:
		_draw_double_joint(1, t_, r, Vector2(40, 32) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2, subdiv)
	t.basis = Basis(Vector3(1, 0, 0), -r.z) * Basis(Vector3(0, 1, 0), r.y) * Basis(Vector3(1, 0, 0), -r.x) * t.basis

	# Draw Right Elbow
	ix = skeleton.find_bone("right_elbow")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(0, t_, r_, Vector2(40, 20) / 64, Vector3(4, 4, 4) / 64, 1, subdiv)
	if draw_l2:
		_draw_single_joint(1, t_, r_, Vector2(40, 36) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2, subdiv)
	t = Transform3D(t.basis * Basis(Vector3(1, 0, 0), r_), t_.origin)

	# Draw Right Hand
	ix = skeleton.find_bone("right_hand")
	t_ = skeleton.get_bone_pose(ix)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	p000 = t_ * Vector3(-1, -1, -1)
	p001 = t_ * Vector3(-1, -1, 1)
	p100 = t_ * Vector3(1, -1, -1)
	p101 = t_ * Vector3(1, -1, 1)
	_draw_cube(
		0,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		t.basis,
		Vector2(40, 24) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(
		0,
		p000,
		p100,
		p001,
		p101,
		-t.basis.y,
		Plane(t.basis.x, -1),
		Vector2(48, 16) / 64,
		Vector2(4, 4) / 64,
	)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			1,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			t.basis,
			Vector2(40, 40) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(
			1,
			p000,
			p100,
			p001,
			p101,
			-t.basis.y,
			Plane(t.basis.x, -1),
			Vector2(48, 32) / 64,
			Vector2(4, 4) / 64,
		)

	# Draw Left Leg
	ix = skeleton.find_bone("left_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(0, t_, r, Vector2(16, 48) / 64, Vector3(4, 4, 4) / 64, true, 1, subdiv)
	if draw_l2:
		_draw_double_joint(1, t_, r, Vector2(0, 48) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2, subdiv)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Left Knee
	ix = skeleton.find_bone("left_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(0, t_, r_, Vector2(16, 52) / 64, Vector3(4, 4, 4) / 64, 1, subdiv)
	if draw_l2:
		_draw_single_joint(1, t_, r_, Vector2(0, 52) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2, subdiv)
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
		0,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		t.basis,
		Vector2(16, 56) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(
		0,
		p000,
		p100,
		p001,
		p101,
		-t.basis.y,
		Plane(t.basis.x, -1),
		Vector2(24, 48) / 64,
		Vector2(4, 4) / 64,
	)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			1,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			t.basis,
			Vector2(0, 56) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(
			1,
			p000,
			p100,
			p001,
			p101,
			-t.basis.y,
			Plane(t.basis.x, -1),
			Vector2(8, 48) / 64,
			Vector2(4, 4) / 64,
		)

	# Draw Right Leg
	ix = skeleton.find_bone("right_leg")
	t = skeleton.get_bone_global_pose(ix)
	r = _get_euler_yxy((t.basis * skin.get_bind_pose(ix).basis).orthonormalized())
	r.y = clampf(r.y, -PI_2, PI_2)
	t.basis = skeleton.get_bone_global_rest(ix).basis
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t.origin)
	_draw_double_joint(0, t_, r, Vector2(0, 16) / 64, Vector3(4, 4, 4) / 64, true, 1, subdiv)
	if draw_l2:
		_draw_double_joint(1, t_, r, Vector2(0, 32) / 64, Vector3(4, 4, 4) / 64, true, 1 + layer2_offset / 2, subdiv)
	t.basis = Basis(Vector3(0, 1, 0), -r.z) * Basis(Vector3(1, 0, 0), -r.y) * Basis(Vector3(0, 1, 0), -r.x) * t.basis

	# Draw Right Knee
	ix = skeleton.find_bone("right_knee")
	t_ = skeleton.get_bone_pose(ix)
	r_ = clampf(t_.basis.orthonormalized().get_euler(EULER_ORDER_XYZ).x, -PI_2, PI_2)
	t_ = Transform3D(t.basis.scaled(Vector3(2, 2, 2)), t * t_.origin)
	_draw_single_joint(0, t_, r_, Vector2(0, 20) / 64, Vector3(4, 4, 4) / 64, 1, subdiv)
	if draw_l2:
		_draw_single_joint(1, t_, r_, Vector2(0, 36) / 64, Vector3(4, 4, 4) / 64, 1 + layer2_offset / 2, subdiv)
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
		0,
		p000,
		p001,
		t_ * Vector3(-1, 1, -1),
		t_ * Vector3(-1, 1, 1),
		p100,
		p101,
		t_ * Vector3(1, 1, -1),
		t_ * Vector3(1, 1, 1),
		t.basis,
		Vector2(0, 24) / 64,
		Vector3(4, 4, 4) / 64,
		0b111100,
	)
	_draw_quad(
		0,
		p000,
		p100,
		p001,
		p101,
		-t.basis.y,
		Plane(t.basis.x, -1),
		Vector2(8, 16) / 64,
		Vector2(4, 4) / 64,
	)
	if draw_l2:
		p000 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p001 = t_ * Vector3(-1 - layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		p100 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, -1 - layer2_offset / 2)
		p101 = t_ * Vector3(1 + layer2_offset / 2, -1 - layer2_offset / 2, 1 + layer2_offset / 2)
		_draw_cube(
			1,
			p000,
			p001,
			t_ * Vector3(-1 - layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(-1 - layer2_offset / 2, 1, 1 + layer2_offset / 2),
			p100,
			p101,
			t_ * Vector3(1 + layer2_offset / 2, 1, -1 - layer2_offset / 2),
			t_ * Vector3(1 + layer2_offset / 2, 1, 1 + layer2_offset / 2),
			t.basis,
			Vector2(0, 40) / 64,
			Vector3(4, 4, 4) / 64,
			0b111100,
		)
		_draw_quad(
			1,
			p000,
			p100,
			p001,
			p101,
			-t.basis.y,
			Plane(t.basis.x, -1),
			Vector2(8, 32) / 64,
			Vector2(4, 4) / 64,
		)

	surfaces[0][0].commit(m)
	m.surface_set_material(0, material)

	if draw_l2:
		surfaces[1][0].commit(m)
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
