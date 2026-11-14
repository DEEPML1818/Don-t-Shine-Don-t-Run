class_name MobileVirtualJoystick
extends Control

## Responsive Virtual Joystick for Mobile Touch Controls
## Supports independent touch tracking (event.index) and clamped 2D vector output.

signal joystick_moved(vector: Vector2)
signal joystick_released()

@export var max_radius: float = 65.0
@export var deadzone: float = 0.1

var touch_index: int = -1
var knob_position: Vector2 = Vector2.ZERO
var output_vector: Vector2 = Vector2.ZERO

var base_color: Color = Color(1.0, 1.0, 1.0, 0.15)
var base_border_color: Color = Color(1.0, 1.0, 1.0, 0.4)
var knob_color: Color = Color(1.0, 1.0, 1.0, 0.7)
var active_knob_color: Color = Color(0.9, 0.7, 0.2, 0.9)

func _ready() -> void:
	# Virtual joystick stops mouse only when actively dragging or touched
	mouse_filter = Control.MOUSE_FILTER_PASS

func _draw() -> void:
	var center = size * 0.5
	# Outer base circle
	draw_circle(center, max_radius, base_color)
	draw_arc(center, max_radius, 0, TAU, 36, base_border_color, 2.0, true)
	
	# Connecting stem if dragged
	if touch_index != -1 and knob_position.length_squared() > 4.0:
		draw_line(center, center + knob_position, Color(1, 1, 1, 0.3), 3.0, true)
	
	# Thumb knob
	var current_knob_color = active_knob_color if touch_index != -1 else knob_color
	draw_circle(center + knob_position, 28.0, current_knob_color)
	draw_arc(center + knob_position, 28.0, 0, TAU, 24, Color.WHITE, 1.5, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1:
				var center = size * 0.5
				var dist = event.position.distance_to(center)
				if dist <= max_radius * 1.5:
					touch_index = event.index
					_update_touch(event.position)
					accept_event()
		else:
			if event.index == touch_index:
				_reset_joystick()
				accept_event()
				
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			_update_touch(event.position)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	# Fallback catch in case drag moves outside bounding rect
	if event is InputEventScreenTouch and not event.pressed:
		if event.index == touch_index:
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == touch_index:
		var local_pos = get_global_transform().affine_inverse() * event.position
		_update_touch(local_pos)

func _update_touch(touch_pos: Vector2) -> void:
	var center = size * 0.5
	var offset = touch_pos - center
	var dist = offset.length()
	
	if dist > max_radius:
		offset = offset.normalized() * max_radius
	
	knob_position = offset
	
	var norm_dist = knob_position.length() / max_radius
	if norm_dist < deadzone:
		output_vector = Vector2.ZERO
	else:
		output_vector = knob_position / max_radius
	
	joystick_moved.emit(output_vector)
	queue_redraw()

func _reset_joystick() -> void:
	touch_index = -1
	knob_position = Vector2.ZERO
	output_vector = Vector2.ZERO
	joystick_released.emit()
	queue_redraw()

func get_output() -> Vector2:
	return output_vector
