extends ColorRect

signal slider_updated(value)

onready var slider: Control = $Content

export(float, 0, 1) var fraction: float = 0 setget set_fraction,get_fraction
export(Color, RGBA) var slider_color: Color = Color.white setget set_color

func get_fraction() -> float:
	return fraction

func set_fraction(v: float):
	fraction = clamp(v, 0, 1)
	if slider != null:
		slider.anchor_right = fraction
	emit_signal("slider_updated", fraction)

func set_color(c: Color):
	slider_color = c
	if slider != null:
		slider.color = c

func _ready():
	slider.anchor_right = fraction
	slider.color = slider_color

func _gui_input(event):
	var mouse: InputEventMouse = event as InputEventMouse
	if mouse != null:
		if (mouse.button_mask & BUTTON_MASK_LEFT) != 0:
			var xmouse: float = mouse.position.x - slider.margin_right
			var xsize: float = rect_size.x
			if is_equal_approx(xsize, 0):
				set_fraction(1 if xmouse > 0 else 0)
			else:
				set_fraction(xmouse / xsize)
		accept_event()
