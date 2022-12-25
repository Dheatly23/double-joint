extends Camera

const ROT_X_SPEED: float = 90.0
const ROT_Y_SPEED: float = 30.0

export(float, EXP, 0.01, 100, 0.01) var dist: float = 1
export var rot_x: float = 0.0 setget set_rot_x
export var rot_y: float = 0.0 setget set_rot_y

func set_rot_x(v: float):
	rot_x = wrapf(v, -180.0, 180.0)
	_update_transform()

func set_rot_y(v: float):
	rot_y = clamp(v, -90.0, 90.0)
	_update_transform()

func _update_transform():
	var r = Quat(Vector3.UP, deg2rad(rot_x)) * Quat(Vector3.LEFT, deg2rad(rot_y))
	transform = Transform(r, r.xform(Vector3.BACK * dist))

func _ready():
	_update_transform()

func _process(delta):
	if Input.is_action_pressed("ui_left"):
		set_rot_x(rot_x - ROT_X_SPEED * delta)
	if Input.is_action_pressed("ui_right"):
		set_rot_x(rot_x + ROT_X_SPEED * delta)
	if Input.is_action_pressed("ui_up"):
		set_rot_y(rot_y + ROT_Y_SPEED * delta)
	if Input.is_action_pressed("ui_down"):
		set_rot_y(rot_y - ROT_Y_SPEED * delta)
