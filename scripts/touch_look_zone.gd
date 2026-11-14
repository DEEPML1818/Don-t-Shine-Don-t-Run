class_name TouchLookZone
extends Control

## Touch Look Zone for Mobile / Touch Camera Control
## Tracks finger drag exclusively on the right half of the screen.
## Emits smooth camera look delta without interfering with joystick or buttons.

signal look_dragged(relative: Vector2)

var touch_index: int = -1

func _ready() -> void:
	# PASS allows children (like action buttons) to intercept touches first
	mouse_filter = Control.MOUSE_FILTER_PASS

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_index == -1:
				touch_index = event.index
				accept_event()
		else:
			if event.index == touch_index:
				touch_index = -1
				accept_event()
				
	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			look_dragged.emit(event.relative)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	# Release tracking if touch ends outside control boundaries
	if event is InputEventScreenTouch and not event.pressed:
		if event.index == touch_index:
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		look_dragged.emit(event.relative)
