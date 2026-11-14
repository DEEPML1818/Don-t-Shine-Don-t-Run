class_name Door
extends Node3D

## A modular, interactive 3D door that pivots on a hinge using Tweens.
## Features open/close states, locked state with jiggle animation, and dynamic prompts.

@export var is_locked: bool = false:
	set(value):
		is_locked = value
		_update_prompt()

@export var open_angle_degrees: float = 90.0
@export var open_speed: float = 0.6
@export var locked_prompt: String = "Door (Locked)"
@export var open_prompt: String = "Close Door"
@export var closed_prompt: String = "Open Door"

@onready var hinge: Node3D = $Hinge
@onready var interactable_body: Interactable = $Hinge/DoorBody

var is_open: bool = false
var is_busy: bool = false
var initial_rotation_y: float = 0.0

func _ready() -> void:
	if hinge:
		initial_rotation_y = hinge.rotation.y
	if interactable_body:
		interactable_body.interacted.connect(_on_interacted)
	_update_prompt()

func _update_prompt() -> void:
	if not interactable_body:
		return
	if is_locked:
		interactable_body.prompt_text = locked_prompt
	elif is_open:
		interactable_body.prompt_text = open_prompt
	else:
		interactable_body.prompt_text = closed_prompt

func _on_interacted(player: Node) -> void:
	interact(player)

## Called when the door is interacted with.
func interact(_player: Node) -> void:
	if is_busy:		return
	
	if is_locked:
		_play_locked_shake()
		return
	
	_toggle_door()

func _toggle_door() -> void:
	is_busy = true
	is_open = not is_open
	_update_prompt()
	
	var target_angle = initial_rotation_y + (deg_to_rad(open_angle_degrees) if is_open else 0.0)
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hinge, "rotation:y", target_angle, open_speed)
	tween.finished.connect(func(): is_busy = false)

func _play_locked_shake() -> void:
	is_busy = true
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var base_rot = hinge.rotation.y
	var jiggle = deg_to_rad(2.0)
	tween.tween_property(hinge, "rotation:y", base_rot + jiggle, 0.06)
	tween.tween_property(hinge, "rotation:y", base_rot - jiggle, 0.06)
	tween.tween_property(hinge, "rotation:y", base_rot + (jiggle * 0.5), 0.06)
	tween.tween_property(hinge, "rotation:y", base_rot, 0.06)
	tween.finished.connect(func(): is_busy = false)
