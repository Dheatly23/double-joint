extends Control

signal value_updated(data: Dictionary)

const boxes: Array[NodePath] = [
	^"VBoxContainer/GridContainer/RightShoulderXSpinBox",
	^"VBoxContainer/GridContainer/RightShoulderYSpinBox",
	^"VBoxContainer/GridContainer/RightShoulderZSpinBox",
	^"VBoxContainer/GridContainer/RightElbowXSpinBox",
	^"VBoxContainer/GridContainer/LeftShoulderXSpinBox",
	^"VBoxContainer/GridContainer/LeftShoulderYSpinBox",
	^"VBoxContainer/GridContainer/LeftShoulderZSpinBox",
	^"VBoxContainer/GridContainer/LeftElbowXSpinBox",
	^"VBoxContainer/GridContainer/RightLegXSpinBox",
	^"VBoxContainer/GridContainer/RightLegYSpinBox",
	^"VBoxContainer/GridContainer/RightLegZSpinBox",
	^"VBoxContainer/GridContainer/RightKneeXSpinBox",
	^"VBoxContainer/GridContainer/LeftLegXSpinBox",
	^"VBoxContainer/GridContainer/LeftLegYSpinBox",
	^"VBoxContainer/GridContainer/LeftLegZSpinBox",
	^"VBoxContainer/GridContainer/LeftKneeXSpinBox",
]

var struct_values := {
	rshoulderx = 0.0,
	rshouldery = 0.0,
	rshoulderz = 0.0,
	relbowx = 0.0,
	lshoulderx = 0.0,
	lshouldery = 0.0,
	lshoulderz = 0.0,
	lelbowx = 0.0,
	rlegx = 0.0,
	rlegy = 0.0,
	rlegz = 0.0,
	rkneex = 0.0,
	llegx = 0.0,
	llegy = 0.0,
	llegz = 0.0,
	lkneex = 0.0,
}

func __changed(value: float, key: String):
	struct_values[key] = value
	emit_signal("value_updated", struct_values.duplicate())

func __reset_all():
	for k in struct_values:
		struct_values[k] = 0.0
	for i in boxes:
		get_node(i).set_value_no_signal(0.0)
	emit_signal("value_updated", struct_values.duplicate())
