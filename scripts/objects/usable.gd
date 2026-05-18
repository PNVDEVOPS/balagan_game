extends Interactable

@export var success_text: String = ""
@export var fail_text: String = "Нужно что-то для этого..."
@export var used: bool = false

signal item_used()

func _ready() -> void:
	super._ready()
	interaction_type = Type.USABLE

func interact(player: CharacterBody2D) -> void:
	if used:
		return
	if required_item.is_empty():
		_on_success()
		return
	if Inventory.selected_item == required_item:
		Inventory.remove_item(required_item)
		_on_success()
	elif not Inventory.selected_item.is_empty():
		DialogueManager.show_text("", "Это здесь не подходит.")
	else:
		DialogueManager.show_text("", fail_text)

func _on_success() -> void:
	used = true
	if not success_text.is_empty():
		DialogueManager.show_text("", success_text)
	item_used.emit()
