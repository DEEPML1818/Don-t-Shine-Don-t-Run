class_name ShadowPuzzle
extends Interactable

const GlobalBus = preload("res://scripts/global_events.gd")

## Rotating Spotlight & Shadow Alignment Pedestal Puzzle
## Interacting rotates the turntable in 45-degree increments.
## When aligned with target_angle, unlocks and opens the connected TrackShelf.

signal puzzle_solved()

@export var target_shelf: TrackShelf
@export var target_angle: float = 180.0
@export var angle_tolerance: float = 5.0

@onready var turntable: Node3D = $Turntable
@onready var spotlight: SpotLight3D = $Turntable/SpotLight3D
@onready var rotate_audio: AudioStreamPlayer3D = $RotateAudio
@onready var solve_audio: AudioStreamPlayer3D = $SolveAudio

var current_angle: float = 0.0
var is_solved: bool = false
var is_busy: bool = false

func _ready() -> void:
	prompt_text = "Rotate Spotlight (45°)"
	if turntable:
		current_angle = turntable.rotation_degrees.y

func _on_interact(_player: Node) -> void:
	if is_solved or is_busy:
		return
		
	is_busy = true
	current_angle = fmod(current_angle + 45.0, 360.0)
	
	if rotate_audio:
		rotate_audio.play()
		
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(turntable, "rotation_degrees:y", current_angle, 0.35)
	tween.finished.connect(_check_alignment)

func _check_alignment() -> void:
	var diff = abs(fposmod(current_angle - target_angle + 180.0, 360.0) - 180.0)
	if diff <= angle_tolerance:
		is_solved = true
		prompt_text = "Spotlight (Aligned)"
		
		if solve_audio:
			solve_audio.play()
			
		if spotlight:
			spotlight.light_color = Color(0.2, 1.0, 0.6, 1.0)
			spotlight.light_energy = 5.0
			
		GlobalBus.emit_noise(global_position, 18.0)
		
		if target_shelf and is_instance_valid(target_shelf):
			target_shelf.open_shelf()
			
		puzzle_solved.emit()
		
	is_busy = false
