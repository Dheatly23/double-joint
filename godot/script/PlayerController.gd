tool
extends Spatial

const LEFT_SHOULDER: int = 2
const LEFT_ELBOW: int = 3
const RIGHT_SHOULDER: int = 5
const RIGHT_ELBOW: int = 6
const LEFT_LEG: int = 8
const LEFT_KNEE: int = 9
const RIGHT_LEG: int = 11
const RIGHT_KNEE: int = 12

export(Texture) var skin_texture: Texture setget set_skin_texture, get_skin_texture

export(float, -180, 180, 0.1) var left_shoulder_x: float setget set_left_shoulder_x, get_left_shoulder_x
export(float, -90, 90, 0.1) var left_shoulder_y: float setget set_left_shoulder_y, get_left_shoulder_y
export(float, -180, 180, 0.1) var left_shoulder_z: float setget set_left_shoulder_z, get_left_shoulder_z
export(float, -90, 90, 0.1) var left_elbow: float setget set_left_elbow, get_left_elbow
export(float, -180, 180, 0.1) var right_shoulder_x: float setget set_right_shoulder_x, get_right_shoulder_x
export(float, -90, 90, 0.1) var right_shoulder_y: float setget set_right_shoulder_y, get_right_shoulder_y
export(float, -180, 180, 0.1) var right_shoulder_z: float setget set_right_shoulder_z, get_right_shoulder_z
export(float, -90, 90, 0.1) var right_elbow: float setget set_right_elbow, get_right_elbow
export(float, -180, 180, 0.1) var left_leg_x: float setget set_left_leg_x, get_left_leg_x
export(float, -90, 90, 0.1) var left_leg_y: float setget set_left_leg_y, get_left_leg_y
export(float, -180, 180, 0.1) var left_leg_z: float setget set_left_leg_z, get_left_leg_z
export(float, -90, 90, 0.1) var left_knee: float setget set_left_knee, get_left_knee
export(float, -180, 180, 0.1) var right_leg_x: float setget set_right_leg_x, get_right_leg_x
export(float, -90, 90, 0.1) var right_leg_y: float setget set_right_leg_y, get_right_leg_y
export(float, -180, 180, 0.1) var right_leg_z: float setget set_right_leg_z, get_right_leg_z
export(float, -90, 90, 0.1) var right_knee: float setget set_right_knee, get_right_knee

onready var _nodes = [
	$Head,
	$Body,
	$LeftArm,
	$LeftArm/LeftArmEnd/LeftElbow,
	$LeftArm/LeftArmEnd/LeftElbow/LeftElbowEnd/LeftHand,
	$RightArm,
	$RightArm/RightArmEnd/RightElbow,
	$RightArm/RightArmEnd/RightElbow/RightElbowEnd/RigthHand,
	$LeftLeg,
	$LeftLeg/LeftLegEnd/LeftKnee,
	$LeftLeg/LeftLegEnd/LeftKnee/LeftKneeEnd/LeftFeet,
	$RightLeg,
	$RightLeg/RightLegEnd/RightKnee,
	$RightLeg/RightLegEnd/RightKnee/RightKneeEnd/RightFeet,
]

func get_skin_texture() -> Texture:
	return skin_texture

func set_skin_texture(v: Texture):
	skin_texture = v

	if _nodes == null:
		return
	for node in _nodes:
		if node is DoubleJoint or node is SingleJoint:
			node.set_skin_texture(v)
		else:
			var material: SpatialMaterial = node.get_material_override()
			material.set_texture(SpatialMaterial.TEXTURE_ALBEDO, v)

func get_left_shoulder_x() -> float:
	if _nodes == null:
		return left_shoulder_x
	return -_nodes[LEFT_SHOULDER].rot_x

func set_left_shoulder_x(v: float):
	if _nodes == null:
		left_shoulder_x = wrapf(v, -180, 180)
		return
	_nodes[LEFT_SHOULDER].rot_x = -v
	left_shoulder_x = -_nodes[LEFT_SHOULDER].rot_x

func get_left_shoulder_y() -> float:
	if _nodes == null:
		return left_shoulder_y
	return _nodes[LEFT_SHOULDER].rot_y

func set_left_shoulder_y(v: float):
	if _nodes == null:
		left_shoulder_y = clamp(v, -90, 90)
		return
	_nodes[LEFT_SHOULDER].rot_y = v
	left_shoulder_y = _nodes[LEFT_SHOULDER].rot_y

func get_left_shoulder_z() -> float:
	return left_shoulder_z

func set_left_shoulder_z(v: float):
	v = wrapf(v, -180, 180)
	left_shoulder_z = v
	if _nodes == null:
		return
	_nodes[LEFT_SHOULDER].rotation.x = deg2rad(v)

func get_left_elbow() -> float:
	if _nodes == null:
		return left_elbow
	return -_nodes[LEFT_ELBOW].rot_x

func set_left_elbow(v: float):
	if _nodes == null:
		left_elbow = clamp(v, -90, 90)
		return
	_nodes[LEFT_ELBOW].rot_x = -v
	left_elbow = -_nodes[LEFT_ELBOW].rot_x

func get_right_shoulder_x() -> float:
	if _nodes == null:
		return right_shoulder_x
	return _nodes[RIGHT_SHOULDER].rot_x

func set_right_shoulder_x(v: float):
	if _nodes == null:
		right_shoulder_x = wrapf(v, -180, 180)
		return
	_nodes[RIGHT_SHOULDER].rot_x = v
	right_shoulder_x = _nodes[RIGHT_SHOULDER].rot_x

func get_right_shoulder_y() -> float:
	if _nodes == null:
		return right_shoulder_y
	return _nodes[RIGHT_SHOULDER].rot_y

func set_right_shoulder_y(v: float):
	if _nodes == null:
		right_shoulder_y = clamp(v, -90, 90)
		return
	_nodes[RIGHT_SHOULDER].rot_y = v
	right_shoulder_y = _nodes[RIGHT_SHOULDER].rot_y

func get_right_shoulder_z() -> float:
	return right_shoulder_z

func set_right_shoulder_z(v: float):
	v = wrapf(v, -180, 180)
	right_shoulder_z = v
	if _nodes == null:
		return
	_nodes[RIGHT_SHOULDER].rotation.x = deg2rad(v)

func get_right_elbow() -> float:
	if _nodes == null:
		return right_elbow
	return -_nodes[RIGHT_ELBOW].rot_x

func set_right_elbow(v: float):
	if _nodes == null:
		right_elbow = clamp(v, -90, 90)
		return
	_nodes[RIGHT_ELBOW].rot_x = -v
	right_elbow = -_nodes[RIGHT_ELBOW].rot_x

func get_left_leg_x() -> float:
	if _nodes == null:
		return left_leg_x
	return -_nodes[LEFT_LEG].rot_x

func set_left_leg_x(v: float):
	if _nodes == null:
		left_leg_x = wrapf(v, -180, 180)
		return
	_nodes[LEFT_LEG].rot_x = -v
	left_leg_x = -_nodes[LEFT_LEG].rot_x

func get_left_leg_y() -> float:
	if _nodes == null:
		return left_leg_y
	return _nodes[LEFT_LEG].rot_y

func set_left_leg_y(v: float):
	if _nodes == null:
		left_leg_y = clamp(v, -90, 90)
		return
	_nodes[LEFT_LEG].rot_y = v
	left_leg_y = _nodes[LEFT_LEG].rot_y

func get_left_leg_z() -> float:
	return left_leg_z

func set_left_leg_z(v: float):
	v = wrapf(v, -180, 180)
	left_leg_z = v
	if _nodes == null:
		return
	_nodes[LEFT_LEG].rotation.y = -deg2rad(v)

func get_left_knee() -> float:
	if _nodes == null:
		return left_knee
	return -_nodes[LEFT_KNEE].rot_x

func set_left_knee(v: float):
	if _nodes == null:
		left_knee = clamp(v, -180, 180)
		return
	_nodes[LEFT_KNEE].rot_x = -v
	left_knee = -_nodes[LEFT_KNEE].rot_x

func get_right_leg_x() -> float:
	if _nodes == null:
		return right_leg_x
	return _nodes[RIGHT_LEG].rot_x

func set_right_leg_x(v: float):
	if _nodes == null:
		right_leg_x = wrapf(v, -180, 180)
		return
	_nodes[RIGHT_LEG].rot_x = v
	right_leg_x = _nodes[RIGHT_LEG].rot_x

func get_right_leg_y() -> float:
	if _nodes == null:
		return right_leg_y
	return _nodes[RIGHT_LEG].rot_y

func set_right_leg_y(v: float):
	if _nodes == null:
		right_leg_y = clamp(v, -90, 90)
		return
	_nodes[RIGHT_LEG].rot_y = v
	right_leg_y = _nodes[RIGHT_LEG].rot_y

func get_right_leg_z() -> float:
	return right_leg_z

func set_right_leg_z(v: float):
	v = wrapf(v, -180, 180)
	right_leg_z = v
	if _nodes == null:
		return
	_nodes[RIGHT_LEG].rotation.y = deg2rad(v)

func get_right_knee() -> float:
	if _nodes == null:
		return right_knee
	return -_nodes[RIGHT_KNEE].rot_x

func set_right_knee(v: float):
	if _nodes == null:
		right_knee = clamp(v, -90, 90)
		return
	_nodes[RIGHT_KNEE].rot_x = -v
	right_knee = -_nodes[RIGHT_KNEE].rot_x

func _ready():
	set_skin_texture(skin_texture)
	set_left_shoulder_x(left_shoulder_x)
	set_left_shoulder_y(left_shoulder_y)
	set_left_shoulder_z(left_shoulder_z)
	set_left_elbow(left_elbow)
	set_right_shoulder_x(right_shoulder_x)
	set_right_shoulder_y(right_shoulder_y)
	set_right_shoulder_z(right_shoulder_z)
	set_right_elbow(right_elbow)
	set_left_leg_x(left_leg_x)
	set_left_leg_y(left_leg_y)
	set_left_leg_z(left_leg_z)
	set_left_knee(left_knee)
	set_right_leg_x(right_leg_x)
	set_right_leg_y(right_leg_y)
	set_right_leg_z(right_leg_z)
	set_right_knee(right_knee)
