class_name MasterKey
extends Interactable

## Master Key Pickup for Warehouse Escape
## When picked up, grants the player master key authorization, updates HUD,
## and plays a pickup chime.

@onready var visual_root: Node3D = $VisualRoot
@onready var pickup_audio: AudioStreamPlayer3D = $PickupAudio
@onready var omni_light: OmniLight3D = $VisualRoot/OmniLight3D

var is_collected: bool = false
var bob_time: float = 0.0

func _ready() -> void:
	prompt_text = "Take Master Key"

func _process(delta: float) -> void:
	if is_collected:
		return
	bob_time += delta
	if visual_root:
		visual_root.rotate_y(delta * 1.5)
		visual_root.position.y = 0.85 + sin(bob_time * 2.5) * 0.05

func _on_interact(player: Node) -> void:
	if is_collected:
		return
	is_collected = true
	can_interact = false
	
	if player.has_method("obtain_master_key"):
		player.obtain_master_key()
		
	if pickup_audio:
		pickup_audio.reparent(get_parent())
		pickup_audio.play()
		pickup_audio.finished.connect(pickup_audio.queue_free)
		
	queue_free()
