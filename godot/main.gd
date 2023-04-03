extends Node3D

func quat_xyz(v: Vector3) -> Quaternion:
	return Quaternion(Vector3(0, 0, 1), v.z) \
		* Quaternion(Vector3(0, 1, 0), v.y) \
		* Quaternion(Vector3(1, 0, 0), v.x)

func __update_skeleton(data: Dictionary):
	var skeleton: Skeleton3D = $Model/Skeleton
	skeleton.reset_bone_poses()

	var ix := skeleton.find_bone("right_arm")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["rshoulderx"]),
			deg_to_rad(data["rshouldery"]),
			deg_to_rad(data["rshoulderz"]),
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("right_elbow")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["relbowx"]),
			0,
			0,
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("left_arm")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["lshoulderx"]),
			deg_to_rad(data["lshouldery"]),
			deg_to_rad(data["lshoulderz"]),
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("left_elbow")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["lelbowx"]),
			0,
			0,
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("right_leg")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["rlegx"]),
			deg_to_rad(data["rlegy"]),
			deg_to_rad(data["rlegz"]),
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("right_knee")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["rkneex"]),
			0,
			0,
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("left_leg")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["llegx"]),
			deg_to_rad(data["llegy"]),
			deg_to_rad(data["llegz"]),
		)) * skeleton.get_bone_pose_rotation(ix)
	)

	ix = skeleton.find_bone("left_knee")
	skeleton.set_bone_pose_rotation(
		ix,
		quat_xyz(Vector3(
			deg_to_rad(data["lkneex"]),
			0,
			0,
		)) * skeleton.get_bone_pose_rotation(ix)
	)
