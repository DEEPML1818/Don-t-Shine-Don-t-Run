extends Node

## Global Event Bus for Warehouse Horror
## Decouples audio events, noise triggers, stalker alerts, and game states.

static var instance: Node = null

signal noise_emitted(origin: Vector3, radius: float)
signal player_escaped()
signal player_caught()

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	instance = self

static func emit_noise(origin: Vector3, radius: float) -> void:
	if instance and instance.has_signal("noise_emitted"):
		instance.noise_emitted.emit(origin, radius)

static func notify_escaped() -> void:
	if instance and instance.has_signal("player_escaped"):
		instance.player_escaped.emit()

static func notify_caught() -> void:
	if instance and instance.has_signal("player_caught"):
		instance.player_caught.emit()

static func connect_noise(callable: Callable) -> void:
	if instance and instance.has_signal("noise_emitted"):
		if not instance.noise_emitted.is_connected(callable):
			instance.noise_emitted.connect(callable)
