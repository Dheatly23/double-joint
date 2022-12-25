extends "res://script/PlayerController.gd"

const PI_2: float = PI / 2

func decompose_rotation(v: Vector3) -> Vector3:
	return Vector3(
		v.z,
		-v.y,
		-(v.x + v.z)
	)

#	var b: Basis = Basis(Quat(Vector3(
#		deg2rad(v.x),
#		deg2rad(v.y),
#		deg2rad(v.z)
#	)))
#
#	var rot_x: float = atan2(b.y.x, b.y.z)
#	var rot_y: float = PI_2 - asin(b.y.y)
#	var z: Vector3 = b.z.rotated(Vector3(cos(rot_x), 0, -sin(rot_x)), -rot_y)
#	var rot_z: float = atan2(z.x, z.z)
#	rot_x -= rot_z
#
#	return Vector3(rad2deg(rot_x), rad2deg(rot_y), rad2deg(rot_z))

func _update_pose_ui(data: Dictionary):
	var left_shoulder: Vector3 = decompose_rotation(Vector3(
		data.lshoulder_rx,
		data.lshoulder_ry,
		data.lshoulder_rz
	))
	set_left_shoulder_x(left_shoulder.x)
	set_left_shoulder_y(left_shoulder.y)
	set_left_shoulder_z(left_shoulder.z)
	set_left_elbow(data.lelbow_r)

	var right_shoulder: Vector3 = decompose_rotation(Vector3(
		data.rshoulder_rx,
		data.rshoulder_ry,
		data.rshoulder_rz
	))
	set_right_shoulder_x(right_shoulder.x)
	set_right_shoulder_y(right_shoulder.y)
	set_right_shoulder_z(right_shoulder.z)
	set_right_elbow(data.relbow_r)

	var left_leg: Vector3 = decompose_rotation(Vector3(
		data.lleg_rx,
		data.lleg_ry,
		data.lleg_rz
	))
	set_left_leg_x(left_leg.x)
	set_left_leg_y(left_leg.y)
	set_left_leg_z(left_leg.z)
	set_left_knee(data.lknee_r)

	var right_leg: Vector3 = decompose_rotation(Vector3(
		data.rleg_rx,
		data.rleg_ry,
		data.rleg_rz
	))
	set_right_leg_x(right_leg.x)
	set_right_leg_y(right_leg.y)
	set_right_leg_z(right_leg.z)
	set_right_knee(data.rknee_r)
