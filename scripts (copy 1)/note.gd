class_name Note
extends Interactable

## An interactive readable note in the 3D world.
## When interacted with, sends its title and content to the player's UI overlay.

@export var note_title: String = "Torn Journal Page"
@export_multiline var note_content: String = "November 14, 1984\n\nIf you find this, keep your flashlight on through the corridor.\nSomething wanders these halls in total darkness.\n\nConserve your stamina—don't run until you hear it approaching.\nFind the exit before the power cuts out completely."

func _ready() -> void:
	prompt_text = "Read Note"

func _on_interact(player: Node) -> void:
	if player.has_method("display_note"):
		player.display_note(note_title, note_content)
