extends Interactable

signal picked_up(item_id: String)

@export var item_id: String = ""
@export var item_name: String = ""
@export var pickup_text: String = ""
@export var item_sprite: Texture2D = null

func _ready() -> void:
	super._ready()
	interaction_type = Type.PICKABLE
	if Inventory.has_item(item_id):
		queue_free()

func interact(_player: CharacterBody2D) -> void:
	if Inventory.add_item(item_id):
		picked_up.emit(item_id)
		if not pickup_text.is_empty():
			var display_name := item_name if not item_name.is_empty() else item_id
			ItemPopup.show_item(display_name, pickup_text, item_sprite)
		queue_free()
