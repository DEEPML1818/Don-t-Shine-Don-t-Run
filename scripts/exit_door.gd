class_name ExitDoor
extends Interactable

## Heavy Industrial Warehouse Exit Door
## Requires Master Key to open.
## If player does not have key: displays locked notification, shakes, and plays rattle.
## If player has key: opens door and triggers "You Escaped" victory screen.

signal exit_opened()

@onready var hinge: Node3D = $Hinge
@onready var door_locked_audio: AudioStreamPlayer3D = $LockedAudio
@onready var door_open_audio: AudioStreamPlayer3D = $OpenAudio

var is_open: bool = false
var is_busy: bool = false
var original_prompt: String = "Open Exit Door"

func _ready() -> void:
	prompt_text = original_prompt

func _on_interact(player: Node) -> void:
	if is_open or is_busy:
		return
		
	var player_has_key = false
	if "has_master_key" in player:
		player_has_key = player.has_master_key
		
	if not player_has_key:
		_play_locked_feedback()
		return
		
	# Unlocking door and escaping
	_open_and_escape(player)

func _play_locked_feedback() -> void:
	is_busy = true
	prompt_text = "Locked - Requires Master Key"
	
	if door_locked_audio:
		door_locked_audio.play()
		
	# Jiggle hinge slightly
	if hinge:
		var base_y = hinge.rotation.y
		var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(hinge, "rotation:y", base_y + deg_to_rad(2.0), 0.05)
		tween.tween_property(hinge, "rotation:y", base_y - deg_to_rad(2.0), 0.05)
		tween.tween_property(hinge, "rotation:y", base_y + deg_to_rad(1.0), 0.05)
		tween.tween_property(hinge, "rotation:y", base_y, 0.05)
		
	# Reset prompt after 2.0s
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		prompt_text = original_prompt
		is_busy = false
	)

func _open_and_escape(player: Node) -> void:
	is_busy = true
	is_open = true
	can_interact = false
	prompt_text = "Escape"
	
	if door_open_audio:
		door_open_audio.play()
		
	if hinge:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hinge, "rotation:y", deg_to_rad(-105.0), 1.2)
		tween.finished.connect(func():
			if player.has_method("trigger_victory"):
				player.trigger_victory()
			exit_opened.emit()
		)
	else:
		if player.has_method("trigger_victory"):
			player.trigger_victory()
		exit_opened.emit()
