class_name Interactable
extends StaticBody3D

## Base class for any interactive object in the game.
## Attach this (or a subclass) to any StaticBody3D to make it interactable by the player.

signal interacted(player: Node)

@export var prompt_text: String = "Interact"
@export var can_interact: bool = true

## Called by the player controller when looking at this object and pressing Interact [E].
func interact(player: Node) -> void:
	if not can_interact:
		return
	_on_interact(player)
	interacted.emit(player)

## Virtual method to override in subclasses (e.g. Door, Note, Key, Switch).
func _on_interact(_player: Node) -> void:
	pass

## Returns the prompt displayed on the player's HUD. Can be overridden for dynamic prompts.
func get_prompt() -> String:
	return prompt_text
