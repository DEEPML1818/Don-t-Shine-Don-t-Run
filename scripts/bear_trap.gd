class_name BearTrap
extends Area3D

## Modular Warehouse Bear Trap
## Snaps shut when stepped on by the player, roots/slows movement to 15%,
## plays an audio cue, and emits a global noise alert for nearby Stalker enemies.

const GlobalBus = preload("res://scripts/global_events.gd")

signal trap_triggered(player: Player)

@export var slow_multiplier: float = 0.15
@export var trap_duration: float = 2.5
@export var noise_radius: float = 25.0
@export var mash_escapes_needed: int = 4

@onready var left_jaw: Node3D = $JawLeft
@onready var right_jaw: Node3D = $JawRight
@onready var snap_audio: AudioStreamPlayer3D = $SnapAudio

var is_sprung: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if is_sprung:
		return
	
	if body is Player:
		spring_trap(body)

func spring_trap(player: Player) -> void:
	is_sprung = true
	
	# Play snap audio cue
	if snap_audio:
		snap_audio.play()
	
	# Animate jaws snapping shut with Tween
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if left_jaw:
		tween.tween_property(left_jaw, "rotation:z", deg_to_rad(75.0), 0.08)
	if right_jaw:
		tween.tween_property(right_jaw, "rotation:z", deg_to_rad(-75.0), 0.08)
	
	# Apply root/slow and mash requirement to player
	player.trap_player(trap_duration, slow_multiplier, mash_escapes_needed)
	
	# Emit global noise alerting any Stalkers in radius
	GlobalBus.emit_noise(global_position, noise_radius)
	trap_triggered.emit(player)
