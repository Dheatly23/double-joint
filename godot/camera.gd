extends Camera3D

const PI_2 := PI / 2
const ROT_SPEED := deg_to_rad(90.0)

var rot_y := 0.0:
	set(v):
		rot_y = clampf(v, -PI_2, PI_2)
		transform.basis = Basis(Quaternion(Vector3.UP, rot_x) * Quaternion(Vector3.LEFT, rot_y))
		transform.origin = transform.basis * Vector3(0, 0, 40)
var rot_x := 0.0:
	set(v):
		rot_x = wrapf(v, -PI, PI)
		transform.basis = Basis(Quaternion(Vector3.UP, rot_x) * Quaternion(Vector3.LEFT, rot_y))
		transform.origin = transform.basis * Vector3(0, 0, 40)

func _process(delta: float):
	if Input.is_action_pressed("ui_up"):
		rot_y += ROT_SPEED * delta
	if Input.is_action_pressed("ui_down"):
		rot_y -= ROT_SPEED * delta
	if Input.is_action_pressed("ui_left"):
		rot_x -= ROT_SPEED * delta
	if Input.is_action_pressed("ui_right"):
		rot_x += ROT_SPEED * delta
