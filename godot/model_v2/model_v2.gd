@tool
extends Node3D

const PI_2 := PI / 2
const SQRT_2 := sqrt(2)
const SQRT_1_2 := sqrt(0.5)

static var BONES := PackedInt32Array([
	0, 65,
	1, 2, 3, 4, 5, 6, 13, 14, 15, 16, 7, 8, 9, 10, 11, 12,
	17, 18, 19, 20, 21, 22, 29, 30, 31, 32, 23, 24, 25, 26, 27, 28,
	33, 34, 35, 36, 37, 38, 45, 46, 47, 48, 39, 40, 41, 42, 43, 44,
	49, 50, 51, 52, 53, 54, 61, 62, 63, 64, 55, 56, 57, 58, 59, 60,
])

const MESH1: NodePath = ^"Mesh/Skeleton3D/mesh_l"
const MESH2: NodePath = ^"Mesh/Skeleton3D/mesh_h"
const SKEL: NodePath = ^"Skeleton"
const SSKEL: NodePath = ^"Mesh/Skeleton3D"

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

func rerender() -> void:
	var m1: MeshInstance3D = get_node(MESH1)
	var m2: MeshInstance3D = get_node(MESH2)
	m1.set_surface_override_material(0, material)
	m2.set_surface_override_material(0, material_layer2)
	m2.visible = material_layer2 != null
	m2.set_blend_shape_value(0, layer2_offset)

func _enter_tree() -> void:
	var s: Skeleton3D = get_node(SKEL)
	s.skeleton_updated.connect(__update)

func _process(_delta: float) -> void:
	if queue_rerender:
		queue_rerender = false

		rerender()

func __update():
	var s: Skeleton3D = get_node(SKEL)
	var s_: Skeleton3D = get_node(SSKEL)

	# Body
	s_.set_bone_pose(BONES[0], s.get_bone_pose(0))
	# Head
	s_.set_bone_pose(BONES[1], s.get_bone_pose(1))

	# Left arm
	__update_djoint(
		s_,
		2,
		-_get_euler_xyx(Basis(s.get_bone_pose_rotation(3) * Quaternion(0, 0, -SQRT_1_2, SQRT_1_2))),
		Quaternion(0, 0, SQRT_1_2, SQRT_1_2),
		false,
	)
	# Left elbow
	__update_sjoint(s_, 12, s.get_bone_pose_rotation(4).get_euler(EULER_ORDER_XYZ).x)

	# Right arm
	__update_djoint(
		s_,
		18,
		_get_euler_xyx(Basis(s.get_bone_pose_rotation(6) * Quaternion(0, 0, SQRT_1_2, SQRT_1_2))),
		Quaternion(0, 0, -SQRT_1_2, SQRT_1_2),
		true,
	)
	# Right elbow
	__update_sjoint(s_, 28, s.get_bone_pose_rotation(7).get_euler(EULER_ORDER_XYZ).x)

	# Left leg
	__update_djoint(
		s_,
		34,
		-_get_euler_yxy(Basis(s.get_bone_pose_rotation(9))),
		Quaternion.IDENTITY,
		true,
	)
	# Left knee
	__update_sjoint(s_, 44, s.get_bone_pose_rotation(10).get_euler(EULER_ORDER_XYZ).x)

	# Right leg
	__update_djoint(
		s_,
		50,
		-_get_euler_yxy(Basis(s.get_bone_pose_rotation(12))),
		Quaternion.IDENTITY,
		true,
	)
	# Right knee
	__update_sjoint(s_, 60, s.get_bone_pose_rotation(13).get_euler(EULER_ORDER_XYZ).x)

static func __update_sjoint(s: Skeleton3D, i: int, r: float) -> void:
	r = clampf(r, -PI_2, PI_2)
	var tz2 := tan(r * 0.5) * 2

	var v0 := Vector3(0, tz2, 0)
	var v1 := Vector3(0, -tz2, 0)

	s.set_bone_pose_position(BONES[i + 1], v0)
	s.set_bone_pose_position(BONES[i + 2], v1)
	s.set_bone_pose_rotation(BONES[i + 3], Quaternion(Vector3(1, 0, 0), r))
	s.set_bone_pose_position(BONES[i + 4], v1)
	s.set_bone_pose_position(BONES[i + 5], v0)

func __update_djoint(s: Skeleton3D, i: int, r: Vector3, q: Quaternion, right_handed: bool) -> void:
	r.y = clampf(r.y, -PI_2, PI_2)
	var sx := sin(r.x)
	var cx := cos(r.x)
	var ty2 := tan(r.y * 0.5) * 2
	if not right_handed:
		ty2 = -ty2

	var v00 := Vector3(0, (-sx - cx) * ty2, 0)
	var v01 := Vector3(0, (-sx + cx) * ty2, 0)
	var v10 := Vector3(0, (sx - cx) * ty2, 0)
	var v11 := Vector3(0, (sx + cx) * ty2, 0)

	s.set_bone_pose_rotation(BONES[i], q * Quaternion(Vector3(0, 1 if right_handed else -1, 0), r.x + r.z))
	s.set_bone_pose_position(BONES[i + 1], v00)
	s.set_bone_pose_position(BONES[i + 2], v01)
	s.set_bone_pose_position(BONES[i + 3], v10)
	s.set_bone_pose_position(BONES[i + 4], v11)
	q = Quaternion(Quaternion(Vector3(0, -1 if right_handed else 1, 0), r.x) * Vector3(1, 0, 0), r.y)
	s.set_bone_pose_rotation(BONES[i + 5], q)
	s.set_bone_pose_position(BONES[i + 6], -v00)
	s.set_bone_pose_position(BONES[i + 7], -v01)
	s.set_bone_pose_position(BONES[i + 8], -v10)
	s.set_bone_pose_position(BONES[i + 9], -v11)

static func _get_euler_xyx(b: Basis) -> Vector3:
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

static func _get_euler_yxy(b: Basis) -> Vector3:
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
