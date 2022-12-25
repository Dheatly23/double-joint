tool
class_name SingleJoint
extends MeshInstance

const PI_2: float = PI / 2
const PARAM_ROT_X: String = "rot_x"
const PARAM_AXIS_Z: String = "axis_z"
const PARAM_SKIN_TEXTURE: String = "skin_texture"
const PARAM_SKIN_SCALE: String = "skin_scale"
const PARAM_SKIN_OFFSET: String = "skin_offset"
const SHADER_SCRIPT: Shader = preload("res://shader/SingleJoint.gdshader")

signal endpoint_transform_updated(transform)

export var skin_texture: Texture setget set_skin_texture
export var skin_scale: Vector2 = Vector2(1, 1) setget set_skin_scale
export var skin_offset: Vector2 setget set_skin_offset

var _shader_l: ShaderMaterial = ShaderMaterial.new()
var _shader_u: ShaderMaterial = ShaderMaterial.new()

export(float, -90, 90, 0.1) var rot_x: float = 0 setget set_rot_x, get_rot_x
export(bool) var axis_z: bool = false setget set_axis_z

func get_rot_x() -> float:
	return rad2deg(rot_x)

func set_rot_x(v: float):
	v = clamp(deg2rad(v), -PI_2, PI_2)
	rot_x = v
	_shader_l.set_shader_param(PARAM_ROT_X, v)
	_shader_u.set_shader_param(PARAM_ROT_X, v)
	update_endpoint_node()

func set_axis_z(v: bool):
	axis_z = v
	_shader_l.set_shader_param(PARAM_AXIS_Z, v)
	_shader_u.set_shader_param(PARAM_AXIS_Z, v)
	update_endpoint_node()

func set_skin_texture(v: Texture):
	skin_texture = v
	_shader_l.set_shader_param(PARAM_SKIN_TEXTURE, skin_texture)
	_shader_u.set_shader_param(PARAM_SKIN_TEXTURE, skin_texture)

func set_skin_scale(v: Vector2):
	skin_scale = v
	_shader_l.set_shader_param(PARAM_SKIN_SCALE, skin_scale)
	_shader_u.set_shader_param(PARAM_SKIN_SCALE, skin_scale)

func set_skin_offset(v: Vector2):
	skin_offset = v
	_shader_l.set_shader_param(PARAM_SKIN_OFFSET, skin_offset)
	_shader_u.set_shader_param(PARAM_SKIN_OFFSET, skin_offset)

func update_endpoint_node():
	var sx: float = sin(rot_x)
	var cx: float = cos(rot_x)
	var basis: Basis
	if (axis_z):
		basis = Basis(Vector3(1, 0, 0), Vector3(0, cx, -sx), Vector3(0, sx, cx))
	else:
		basis = Basis(Vector3(cx, -sx, 0), Vector3(sx, cx, 0), Vector3(0, 0, 1))
	emit_signal("endpoint_transform_updated", Transform(
		basis, basis * (Vector3.UP * 0.5)
	))

#func _add_face(
#	v1: Vector3,
#	vt1: Vector2,
#	v2: Vector3,
#	vt2: Vector2,
#	v3: Vector3,
#	vt3: Vector2,
#	v4: Vector3,
#	vt4: Vector2,
#	n: Vector3,
#	size: int,
#	st: SurfaceTool,
#	offset: int
#) -> int:
#
#	for y in range(size + 1):
#		var dy: float = float(y) / size
#		for x in range(size + 1):
#			var dx: float = float(x) / size
#
#			st.add_normal(n)
#			st.add_uv(lerp(
#				lerp(vt1, vt2, dx),
#				lerp(vt3, vt4, dx),
#				dy
#			))
#			st.add_vertex(lerp(
#				lerp(v1, v2, dx),
#				lerp(v3, v4, dx),
#				dy
#			))
#
#	for y in range(size):
#		var dy: float = (y + 0.5) / size
#		for x in range(size):
#			var dx: float = (x + 0.5) / size
#
#			st.add_normal(n)
#			st.add_uv(lerp(
#				lerp(vt1, vt2, dx),
#				lerp(vt3, vt4, dx),
#				dy
#			))
#			st.add_vertex(lerp(
#				lerp(v1, v2, dx),
#				lerp(v3, v4, dx),
#				dy
#			))
#
#	var offset_odd: int = offset + (size + 1) * (size + 1)
#	for y in range(size):
#		for x in range(size):
#			var ix1: int = y * (size + 1) + x + offset
#			var ix2: int = ix1 + 1
#			var ix3: int = ix2 + size
#			var ix4: int = ix3 + 1
#			var ix5: int = y * size + x + offset_odd
#
#			st.add_index(ix1)
#			st.add_index(ix2)
#			st.add_index(ix5)
#			st.add_index(ix1)
#			st.add_index(ix5)
#			st.add_index(ix3)
#			st.add_index(ix2)
#			st.add_index(ix4)
#			st.add_index(ix5)
#			st.add_index(ix3)
#			st.add_index(ix5)
#			st.add_index(ix4)
#
#	return offset_odd + size * size

func _ready():
#	mesh = ArrayMesh.new()
#	var st: SurfaceTool = SurfaceTool.new()
#	var offset: int = 0
#	st.begin(Mesh.PRIMITIVE_TRIANGLES)
#	offset = _add_face(
#		Vector3(-0.5, -0.5, -0.5),
#		Vector2(0.5, 0),
#		Vector3(-0.5, -0.5, 0.5),
#		Vector2(0.5, 0.5),
#		Vector3(0.5, -0.5, -0.5),
#		Vector2(0.25, 0),
#		Vector3(0.5, -0.5, 0.5),
#		Vector2(0.25, 0.5),
#		Vector3.DOWN,
#		1,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(-0.5, -0.5, -0.5),
#		Vector2(0.75, 0.5),
#		Vector3(-0.5, 0, -0.5),
#		Vector2(0.75, 0.75),
#		Vector3(-0.5, -0.5, 0.5),
#		Vector2(0.5, 0.5),
#		Vector3(-0.5, 0, 0.5),
#		Vector2(0.5, 0.75),
#		Vector3.LEFT,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(-0.5, -0.5, 0.5),
#		Vector2(0.5, 0.5),
#		Vector3(-0.5, 0, 0.5),
#		Vector2(0.5, 0.75),
#		Vector3(0.5, -0.5, 0.5),
#		Vector2(0.25, 0.5),
#		Vector3(0.5, 0, 0.5),
#		Vector2(0.25, 0.75),
#		Vector3.BACK,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(0.5, -0.5, 0.5),
#		Vector2(0.25, 0.5),
#		Vector3(0.5, 0, 0.5),
#		Vector2(0.25, 0.75),
#		Vector3(0.5, -0.5, -0.5),
#		Vector2(0, 0.5),
#		Vector3(0.5, 0, -0.5),
#		Vector2(0, 0.75),
#		Vector3.RIGHT,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(0.5, -0.5, -0.5),
#		Vector2(1, 0.5),
#		Vector3(0.5, 0, -0.5),
#		Vector2(1, 0.75),
#		Vector3(-0.5, -0.5, -0.5),
#		Vector2(0.75, 0.5),
#		Vector3(-0.5, 0, -0.5),
#		Vector2(0.75, 0.75),
#		Vector3.FORWARD,
#		2,
#		st,
#		offset
#	)
#	mesh = st.commit(mesh)
#
#	offset = 0
#	st.begin(Mesh.PRIMITIVE_TRIANGLES)
#	offset = _add_face(
#		Vector3(-0.5, 0.5, -0.5),
#		Vector2(0.75, 0),
#		Vector3(0.5, 0.5, -0.5),
#		Vector2(0.5, 0),
#		Vector3(-0.5, 0.5, 0.5),
#		Vector2(0.75, 0.5),
#		Vector3(0.5, 0.5, 0.5),
#		Vector2(0.5, 0.5),
#		Vector3.UP,
#		1,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(-0.5, 0, -0.5),
#		Vector2(0.75, 0.75),
#		Vector3(-0.5, 0.5, -0.5),
#		Vector2(0.75, 1),
#		Vector3(-0.5, 0, 0.5),
#		Vector2(0.5, 0.75),
#		Vector3(-0.5, 0.5, 0.5),
#		Vector2(0.5, 1),
#		Vector3.LEFT,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(-0.5, 0, 0.5),
#		Vector2(0.5, 0.75),
#		Vector3(-0.5, 0.5, 0.5),
#		Vector2(0.5, 1),
#		Vector3(0.5, 0, 0.5),
#		Vector2(0.25, 0.75),
#		Vector3(0.5, 0.5, 0.5),
#		Vector2(0.25, 1),
#		Vector3.BACK,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(0.5, 0, 0.5),
#		Vector2(0.25, 0.75),
#		Vector3(0.5, 0.5, 0.5),
#		Vector2(0.25, 1),
#		Vector3(0.5, 0, -0.5),
#		Vector2(0, 0.75),
#		Vector3(0.5, 0.5, -0.5),
#		Vector2(0, 1),
#		Vector3.RIGHT,
#		2,
#		st,
#		offset
#	)
#	offset = _add_face(
#		Vector3(0.5, 0, -0.5),
#		Vector2(1, 0.75),
#		Vector3(0.5, 0.5, -0.5),
#		Vector2(1, 1),
#		Vector3(-0.5, 0, -0.5),
#		Vector2(0.75, 0.75),
#		Vector3(-0.5, 0.5, -0.5),
#		Vector2(0.75, 1),
#		Vector3.FORWARD,
#		2,
#		st,
#		offset
#	)
#	mesh = st.commit(mesh)

	set_surface_material(0, _shader_l)
	set_surface_material(1, _shader_u)

	_shader_l.shader = SHADER_SCRIPT
	_shader_l.set_shader_param("rotated", false)
	_shader_l.set_shader_param(PARAM_SKIN_TEXTURE, skin_texture)
	_shader_l.set_shader_param(PARAM_SKIN_SCALE, skin_scale)
	_shader_l.set_shader_param(PARAM_SKIN_OFFSET, skin_offset)
	_shader_l.set_shader_param(PARAM_ROT_X, rot_x)
	_shader_l.set_shader_param(PARAM_AXIS_Z, axis_z)
	_shader_u.shader = SHADER_SCRIPT
	_shader_u.set_shader_param("rotated", true)
	_shader_u.set_shader_param(PARAM_SKIN_TEXTURE, skin_texture)
	_shader_u.set_shader_param(PARAM_SKIN_SCALE, skin_scale)
	_shader_u.set_shader_param(PARAM_SKIN_OFFSET, skin_offset)
	_shader_u.set_shader_param(PARAM_ROT_X, rot_x)
	_shader_u.set_shader_param(PARAM_AXIS_Z, axis_z)
