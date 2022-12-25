tool
extends ImmediateGeometry

const ROOT_2 = sqrt(2)
const ROOT_2_2 = ROOT_2 / 2

export var texture: Texture setget set_texture, get_texture

var _do_update: bool = false

export(float) var lshoulder_rx: float = 0 setget set_lshoulder_rx, get_lshoulder_rx
export(float, -90, 90) var lshoulder_ry: float = 0 setget set_lshoulder_ry, get_lshoulder_ry
export(float) var lshoulder_rz: float = 0 setget set_lshoulder_rz, get_lshoulder_rz
export(float, -90, 90) var lelbow_r: float = 0 setget set_lelbow_r, get_lelbow_r

export(float) var rshoulder_rx: float = 0 setget set_rshoulder_rx, get_rshoulder_rx
export(float, -90, 90) var rshoulder_ry: float = 0 setget set_rshoulder_ry, get_rshoulder_ry
export(float) var rshoulder_rz: float = 0 setget set_rshoulder_rz, get_rshoulder_rz
export(float, -90, 90) var relbow_r: float = 0 setget set_relbow_r, get_relbow_r

export(float) var lleg_rx: float = 0 setget set_lleg_rx, get_lleg_rx
export(float, -90, 90) var lleg_ry: float = 0 setget set_lleg_ry, get_lleg_ry
export(float) var lleg_rz: float = 0 setget set_lleg_rz, get_lleg_rz
export(float, -90, 90) var lknee_r: float = 0 setget set_lknee_r, get_lknee_r

export(float) var rleg_rx: float = 0 setget set_rleg_rx, get_rleg_rx
export(float, -90, 90) var rleg_ry: float = 0 setget set_rleg_ry, get_rleg_ry
export(float) var rleg_rz: float = 0 setget set_rleg_rz, get_rleg_rz
export(float, -90, 90) var rknee_r: float = 0 setget set_rknee_r, get_rknee_r

# Texture
func get_texture() -> Texture:
	return texture

func set_texture(t: Texture):
	texture = t
	queue_update()

# Getters
func get_lshoulder_rx() -> float:
	return rad2deg(lshoulder_rx)

func get_lshoulder_ry() -> float:
	return rad2deg(lshoulder_ry)

func get_lshoulder_rz() -> float:
	return rad2deg(lshoulder_rz)

func get_lelbow_r() -> float:
	return rad2deg(lelbow_r)

func get_rshoulder_rx() -> float:
	return rad2deg(rshoulder_rx)

func get_rshoulder_ry() -> float:
	return rad2deg(rshoulder_ry)

func get_rshoulder_rz() -> float:
	return rad2deg(rshoulder_rz)

func get_relbow_r() -> float:
	return rad2deg(relbow_r)

func get_lleg_rx() -> float:
	return rad2deg(lleg_rx)

func get_lleg_ry() -> float:
	return rad2deg(lleg_ry)

func get_lleg_rz() -> float:
	return rad2deg(lleg_rz)

func get_lknee_r() -> float:
	return rad2deg(lknee_r)

func get_rleg_rx() -> float:
	return rad2deg(rleg_rx)

func get_rleg_ry() -> float:
	return rad2deg(rleg_ry)

func get_rleg_rz() -> float:
	return rad2deg(rleg_rz)

func get_rknee_r() -> float:
	return rad2deg(rknee_r)

# Setters
func set_lshoulder_rx(v: float):
	lshoulder_rx = deg2rad(v)
	queue_update()

func set_lshoulder_ry(v: float):
	lshoulder_ry = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_lshoulder_rz(v: float):
	lshoulder_rz = deg2rad(v)
	queue_update()

func set_lelbow_r(v: float):
	lelbow_r = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_rshoulder_rx(v: float):
	rshoulder_rx = deg2rad(v)
	queue_update()

func set_rshoulder_ry(v: float):
	rshoulder_ry = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_rshoulder_rz(v: float):
	rshoulder_rz = deg2rad(v)
	queue_update()

func set_relbow_r(v: float):
	relbow_r = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_lleg_rx(v: float):
	lleg_rx = deg2rad(v)
	queue_update()

func set_lleg_ry(v: float):
	lleg_ry = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_lleg_rz(v: float):
	lleg_rz = deg2rad(v)
	queue_update()

func set_lknee_r(v: float):
	lknee_r = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_rleg_rx(v: float):
	rleg_rx = deg2rad(v)
	queue_update()

func set_rleg_ry(v: float):
	rleg_ry = deg2rad(clamp(v, -90, 90))
	queue_update()

func set_rleg_rz(v: float):
	rleg_rz = deg2rad(v)
	queue_update()

func set_rknee_r(v: float):
	rknee_r = deg2rad(clamp(v, -90, 90))
	queue_update()

# Update mesh
func update():
	clear()
	if texture == null:
		return

	begin(Mesh.PRIMITIVE_TRIANGLES, texture)

	var tv = Vector2(1, 1) / texture.get_size()
	var tv3 = Vector3(tv.x, tv.y, tv.x)

	var uv_orig: Vector2
	var net_size: Vector3
	var tr: Transform

	# Head
	_draw_cube(
		[
			Vector3(-4, 0, -4),
			Vector3(-4, 0, 4),
			Vector3(-4, 8, 4),
			Vector3(-4, 8, -4),
			Vector3(4, 0, -4),
			Vector3(4, 0, 4),
			Vector3(4, 8, 4),
			Vector3(4, 8, -4),
		],
		Vector2(0, 0) * tv,
		Vector3(8, 8, 8) * tv3
	)

	# Body
	_draw_cube(
		[
			Vector3(-4, -16, -2),
			Vector3(-4, -16, 2),
			Vector3(-4, 0, 2),
			Vector3(-4, 0, -2),
			Vector3(4, -16, -2),
			Vector3(4, -16, 2),
			Vector3(4, 0, 2),
			Vector3(4, 0, -2),
		],
		Vector2(16, 16) * tv,
		Vector3(8, 16, 4) * tv3
	)

	uv_orig = Vector2(32, 48) * tv
	net_size = Vector3(4, 4, 4) * tv3
	tr = Transform(Basis(Vector3.UP, lshoulder_rx + lshoulder_rz))
	tr = Transform(
		Vector3(0, 4, 0),
		Vector3(-4, 0, 0),
		Vector3(0, 0, 4),
		Vector3(4, -2, 0)
	) * tr

	# Left Shoulder
	tr = _draw_djoint(
		-lshoulder_rz, -lshoulder_ry,
		tr,
		uv_orig,
		net_size,
		0b101111
	)

	# Left Elbow
	tr = _draw_sjoint(
		-lelbow_r,
		tr,
		uv_orig,
		net_size,
		0b001111,
		net_size.y
	)

	# Left Hand
	_draw_cube(
		[
			tr * Vector3(-0.5, -1, -0.5),
			tr * Vector3(-0.5, -1, 0.5),
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			tr * Vector3(0.5, -1, -0.5),
			tr * Vector3(0.5, -1, 0.5),
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		0b011111,
		net_size.y * 2
	)

	uv_orig = Vector2(40, 16) * tv
	net_size = Vector3(4, 4, 4) * tv3
	tr = Transform(Basis(Vector3.DOWN, rshoulder_rx + rshoulder_rz))
	tr = Transform(
		Vector3(0, -4, 0),
		Vector3(4, 0, 0),
		Vector3(0, 0, 4),
		Vector3(-4, -2, 0)
	) * tr

	# Right Shoulder
	tr = _draw_djoint(
		rshoulder_rz, -rshoulder_ry,
		tr,
		uv_orig,
		net_size,
		0b101111
	)

	# Right Elbow
	tr = _draw_sjoint(
		-relbow_r,
		tr,
		uv_orig,
		net_size,
		0b001111,
		net_size.y
	)

	# Right Hand
	_draw_cube(
		[
			tr * Vector3(-0.5, -1, -0.5),
			tr * Vector3(-0.5, -1, 0.5),
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			tr * Vector3(0.5, -1, -0.5),
			tr * Vector3(0.5, -1, 0.5),
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		0b011111,
		net_size.y * 2
	)

	uv_orig = Vector2(16, 48) * tv
	net_size = Vector3(4, 4, 4) * tv3
	tr = Transform(Basis(Vector3.UP, lleg_rx + lleg_rz))
	tr = Transform(
		Vector3(4, 0, 0),
		Vector3(0, 4, 0),
		Vector3(0, 0, 4),
		Vector3(2, -16, 0)
	) * tr

	# Left Leg
	tr = _draw_djoint(
		-lleg_rz, -lleg_ry,
		tr,
		uv_orig,
		net_size,
		0b101111
	)

	# Left Knee
	tr = _draw_sjoint(
		-lknee_r,
		tr,
		uv_orig,
		net_size,
		0b001111,
		net_size.y
	)

	# Left Feet
	_draw_cube(
		[
			tr * Vector3(-0.5, -1, -0.5),
			tr * Vector3(-0.5, -1, 0.5),
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			tr * Vector3(0.5, -1, -0.5),
			tr * Vector3(0.5, -1, 0.5),
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		0b011111,
		net_size.y * 2
	)

	uv_orig = Vector2(0, 16) * tv
	net_size = Vector3(4, 4, 4) * tv3
	tr = Transform(Basis(Vector3.DOWN, rleg_rx + rleg_rz))
	tr = Transform(
		Vector3(4, 0, 0),
		Vector3(0, 4, 0),
		Vector3(0, 0, 4),
		Vector3(-2, -16, 0)
	) * tr

	# Right Leg
	tr = _draw_djoint(
		rleg_rz, -rleg_ry,
		tr,
		uv_orig,
		net_size,
		0b101111
	)

	# Right Knee
	tr = _draw_sjoint(
		-rknee_r,
		tr,
		uv_orig,
		net_size,
		0b001111,
		net_size.y
	)

	# Right Feet
	_draw_cube(
		[
			tr * Vector3(-0.5, -1, -0.5),
			tr * Vector3(-0.5, -1, 0.5),
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			tr * Vector3(0.5, -1, -0.5),
			tr * Vector3(0.5, -1, 0.5),
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		0b011111,
		net_size.y * 2
	)

	end()

# Queues update on next call to _process()
func queue_update():
	_do_update = true

# Drawing functions

func _draw_triangle(
	v1: Vector3,
	uv1: Vector2,
	v2: Vector3,
	uv2: Vector2,
	v3: Vector3,
	uv3: Vector2
):
	var norm: Vector3 = (v3 - v1).cross(v2 - v1)
#	if norm.is_equal_approx(Vector3.ZERO):
#		return

	set_normal(norm.normalized())
	set_uv(uv1)
	add_vertex(v1)
	set_uv(uv2)
	add_vertex(v2)
	set_uv(uv3)
	add_vertex(v3)

func _is_vec3_eq_approx(a: Vector3, b: Vector3, epsilon: float = 1e-5) -> bool:
	return abs((b - a).length_squared()) <= epsilon

func _test_inplane(v1, v2, v3, v4):
	if _is_vec3_eq_approx(v1, v2, 1e-3) or _is_vec3_eq_approx(v1, v4, 1e-3) or _is_vec3_eq_approx(v2, v4, 1e-3):
		return true
	var plane = Plane(v1, v2, v4)
	if !plane.has_point(v3, 1e-3):
		printerr("Point {0} is not in plane ({1}, {2}, {3}) (has distance {4})".format([v3, v1, v2, v4, plane.distance_to(v3)]))
		return false
	return true

func _draw_plane(
	v1: Vector3,
	uv1: Vector2,
	v2: Vector3,
	uv2: Vector2,
	v3: Vector3,
	uv3: Vector2,
	v4: Vector3,
	uv4: Vector2,
	flipped: bool = false
):
	assert(_test_inplane(v1, v2, v3, v4))
	if !flipped:
		_draw_triangle(
			v1, uv1,
			v2, uv2,
			v4, uv4
		)
		_draw_triangle(
			v2, uv2,
			v3, uv3,
			v4, uv4
		)
	else:
		_draw_triangle(
			v2, uv2,
			v1, uv1,
			v4, uv4
		)
		_draw_triangle(
			v3, uv3,
			v2, uv2,
			v4, uv4
		)

func _draw_plane2(
	v1: Vector3,
	v2: Vector3,
	v3: Vector3,
	v4: Vector3,
	p: Vector2,
	dp: Vector2,
	flipped: bool = false
):
	_draw_plane(
		v1, p,
		v2, Vector2(p.x + dp.x, p.y),
		v3, p + dp,
		v4, Vector2(p.x, p.y + dp.y),
		flipped
	)

# Corner order is (xyz):
# 000, 001, 011, 010, 100, 101, 111, 110
#
# Mask bits (MSB-LSB):
# U D L R F B
func _draw_cube(
	corners,
	uv_orig: Vector2,
	net_size: Vector3,
	mask: int = 0b111111,
	side_offset: float = 0
):
	# Front
	if mask & 2:
		_draw_plane2(
			corners[2],
			corners[6],
			corners[5],
			corners[1],
			uv_orig + Vector2(net_size.z, net_size.z + side_offset),
			Vector2(net_size.x, net_size.y)
		)

	# Back
	if mask & 1:
		_draw_plane2(
			corners[7],
			corners[3],
			corners[0],
			corners[4],
			uv_orig + Vector2(net_size.x + net_size.z * 2, net_size.z + side_offset),
			Vector2(net_size.x, net_size.y)
		)

	# Right
	if mask & 4:
		_draw_plane2(
			corners[3],
			corners[2],
			corners[1],
			corners[0],
			uv_orig + Vector2(0, net_size.z + side_offset),
			Vector2(net_size.z, net_size.y)
		)

	# Left
	if mask & 8:
		_draw_plane2(
			corners[6],
			corners[7],
			corners[4],
			corners[5],
			uv_orig + Vector2(net_size.x + net_size.z, net_size.z + side_offset),
			Vector2(net_size.z, net_size.y)
		)

	# Up
	if mask & 32:
		_draw_plane2(
			corners[3],
			corners[7],
			corners[6],
			corners[2],
			uv_orig + Vector2(net_size.z, 0),
			Vector2(net_size.x, net_size.z)
		)

	# Down
	if mask & 16:
		_draw_plane2(
			corners[0],
			corners[4],
			corners[5],
			corners[1],
			uv_orig + Vector2(net_size.x + net_size.z, 0),
			Vector2(net_size.x, net_size.z),
			true
		)

func _draw_sjoint(
	rot: float,
	tr: Transform,
	uv_orig: Vector2,
	net_size: Vector3,
	mask: int = 0b111111,
	size_offset: float = 0
) -> Transform:
	rot = clamp(rot, -PI/2, PI/2)
	var rt: Transform = Transform(Basis(Vector3.RIGHT, rot))
	rt.origin = rt.basis.y * -0.5
	rt.origin.y -= 0.5
	rt = tr * rt

	rot *= 0.5
	var tx: float = tan(rot) * 0.5
	var mid00 = tr * Vector3(-0.5, -0.5 + tx, -0.5)
	var mid01 = tr * Vector3(-0.5, -0.5 - tx, 0.5)
	var mid11 = tr * Vector3(0.5, -0.5 - tx, 0.5)
	var mid10 = tr * Vector3(0.5, -0.5 + tx, -0.5)

	var up00 = rt * Vector3(-0.5, 0, -0.5)
	var up01 = rt * Vector3(-0.5, 0, 0.5)
	var up11 = rt * Vector3(0.5, 0, 0.5)
	var up10 = rt * Vector3(0.5, 0, -0.5)

	net_size.y *= 0.5

	_draw_cube(
		[
			mid00,
			mid01,
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			mid10,
			mid11,
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		mask & 0b101111,
		size_offset
	)
	_draw_cube(
		[
			up00,
			up01,
			mid01,
			mid00,
			up10,
			up11,
			mid11,
			mid10,
		],
		uv_orig,
		net_size,
		mask & 0b011111,
		size_offset + net_size.y
	)

	return rt

func _draw_djoint(
	rx: float,
	ry: float,
	tr: Transform,
	uv_orig: Vector2,
	net_size: Vector3,
	mask: int = 0b111111
) -> Transform:
	rx = wrapf(rx, -PI, PI)
	ry = clamp(ry, -PI/2, PI/2)

	var qx: Quat = Quat(Vector3.UP, rx)
	var rt: Transform = Transform(Quat(qx * Vector3.RIGHT, ry))
	rt.origin = rt.basis.y * -ROOT_2_2
	rt.origin.y -= ROOT_2_2
	rt = tr * rt

	ry *= 0.5
	var temp: float = tan(ry)
	var v: Vector3 = qx * Vector3.FORWARD * 0.5
	var mid00 = tr * Vector3(-0.5, -ROOT_2_2 + -(v.x + v.z) * temp, -0.5)
	var mid01 = tr * Vector3(-0.5, -ROOT_2_2 + (v.z - v.x) * temp, 0.5)
	var mid11 = tr * Vector3(0.5, -ROOT_2_2 + (v.x + v.z) * temp, 0.5)
	var mid10 = tr * Vector3(0.5, -ROOT_2_2 + (v.x - v.z) * temp, -0.5)

	var up00 = rt * Vector3(-0.5, 0, -0.5)
	var up01 = rt * Vector3(-0.5, 0, 0.5)
	var up11 = rt * Vector3(0.5, 0, 0.5)
	var up10 = rt * Vector3(0.5, 0, -0.5)

	net_size.y *= 0.5

	_draw_cube(
		[
			mid00,
			mid01,
			tr * Vector3(-0.5, 0, 0.5),
			tr * Vector3(-0.5, 0, -0.5),
			mid10,
			mid11,
			tr * Vector3(0.5, 0, 0.5),
			tr * Vector3(0.5, 0, -0.5),
		],
		uv_orig,
		net_size,
		mask & 0b101111
	)
	_draw_cube(
		[
			up00,
			up01,
			mid01,
			mid00,
			up10,
			up11,
			mid11,
			mid10,
		],
		uv_orig,
		net_size,
		mask & 0b011111,
		net_size.y
	)

	return rt

# Other

func _ready():
	update()

func _process(_delta):
	if _do_update:
		update()
		_do_update = false

func _update_pose_ui(data):
	for key in data:
		set(key, data[key])
