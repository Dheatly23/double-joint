tool
extends Spatial

const SQRT_1_2: float = sqrt(0.5)

var _rot_x: float = 0
var _rot_y: float = 0

func update_self_rot(value_rad, discriminant):
	match discriminant:
		0:
			_rot_x = value_rad
		1:
			_rot_y = value_rad

	transform = Transform(
		Basis.IDENTITY, Vector3.UP * SQRT_1_2
	).rotated(Vector3(sin(_rot_x), 0, cos(_rot_x)), _rot_y)
