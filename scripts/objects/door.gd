extends Interactable

@export var door_id: String = ""
@export var locked: bool = false
@export var lock_message: String = "Дверь заперта..."

func _ready() -> void:
	super._ready()
	interaction_type = Type.DOOR

func interact(player: CharacterBody2D) -> void:
	if locked:
		if not required_item.is_empty() and Inventory.has_item(required_item):
			locked = false
			Inventory.remove_item(required_item)
			DialogueManager.show_text("", "Дверь открылась.")
			await DialogueManager.dialogue_finished
			GameManager.change_room(door_id)
		else:
			DialogueManager.show_text("", lock_message)
	elif GameManager.get_door_target(GameManager.current_room, door_id).is_empty():
		DialogueManager.show_text("", lock_message)
	else:
		GameManager.change_room(door_id)
