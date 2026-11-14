class_name TrackShelf
extends AnimatableBody3D

## Heavy Industrial Warehouse Shelf on Floor Rails
## Slides open or closed via smooth Tweens to reveal secret corridors or bypass obstacles.

signal shelf_opened()
signal shelf_closed()

@export var slide_offset: Vector3 = Vector3(3.0, 0.0, 0.0)
@export var slide_duration: float = 1.5
@export var is_open_initially: bool = false

var is_open: bool = false
var initial_position: Vector3
var current_tween: Tween = null

@onready var slide_audio: AudioStreamPlayer3D = $SlideAudio

func _ready() -> void:
	initial_position = position
	if is_open_initially:
		position = initial_position + slide_offset
		is_open = true

func open_shelf() -> void:
	if is_open:
		return
	is_open = true
	_animate_to(initial_position + slide_offset, true)

func close_shelf() -> void:
	if not is_open:
		return
	is_open = false
	_animate_to(initial_position, false)

func toggle_shelf() -> void:
	if is_open:
		close_shelf()
	else:
		open_shelf()

func _animate_to(target_pos: Vector3, opening: bool) -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		
	if slide_audio:
		slide_audio.play()
		
	current_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	current_tween.tween_property(self, "position", target_pos, slide_duration)
	current_tween.finished.connect(func():
		if opening:
			shelf_opened.emit()
		else:
			shelf_closed.emit()
	)
