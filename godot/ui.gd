extends Control

signal value_updated(data: Dictionary)

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
