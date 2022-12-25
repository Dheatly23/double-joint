extends Control

signal pose_updated(data)

var _slider_data: Dictionary = {
	lshoulder_rx = 0.0,
	lshoulder_ry = 0.0,
	lshoulder_rz = 0.0,
	lelbow_r = 0.0,
	rshoulder_rx = 0.0,
	rshoulder_ry = 0.0,
	rshoulder_rz = 0.0,
	relbow_r = 0.0,
	lleg_rx = 0.0,
	lleg_ry = 0.0,
	lleg_rz = 0.0,
	lknee_r = 0.0,
	rleg_rx = 0.0,
	rleg_ry = 0.0,
	rleg_rz = 0.0,
	rknee_r = 0.0,
}

var _slider_param = {
	lshoulder_rx = true,
	lshoulder_ry = false,
	lshoulder_rz = true,
	lelbow_r = false,
	rshoulder_rx = true,
	rshoulder_ry = false,
	rshoulder_rz = true,
	relbow_r = false,
	lleg_rx = true,
	lleg_ry = false,
	lleg_rz = true,
	lknee_r = false,
	rleg_rx = true,
	rleg_ry = false,
	rleg_rz = true,
	rknee_r = false,
}

onready var sliders = [
	$GridContainer/LShoulderX,
	$GridContainer/LShoulderY,
	$GridContainer/LShoulderZ,
	$GridContainer/LElbow,
	$GridContainer/RShoulderX,
	$GridContainer/RShoulderY,
	$GridContainer/RShoulderZ,
	$GridContainer/RElbow,
	$GridContainer/LLegX,
	$GridContainer/LLegY,
	$GridContainer/LLegZ,
	$GridContainer/LKnee,
	$GridContainer/RLegX,
	$GridContainer/RLegY,
	$GridContainer/RLegZ,
	$GridContainer/RKnee,
]

func _update_slider(value, key):
	if key in _slider_data:
		if _slider_param[key]:
			value = (value - 0.5) * 360
		else:
			value = (value - 0.5) * 180
		_slider_data[key] = value
		emit_signal("pose_updated", _slider_data)

func _reset_values():
	for node in sliders:
		node.set_fraction(0.5)
