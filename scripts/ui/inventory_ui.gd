extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var item_list: HBoxContainer = $Panel/MarginContainer/HBoxContainer

var is_open: bool = false

func _ready() -> void:
	panel.visible = false
	Inventory.inventory_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()

func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	if is_open:
		_refresh()

func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for item_id in Inventory.items:
		var btn := Button.new()
		btn.text = item_id
		btn.custom_minimum_size = Vector2(64, 64)
		if Inventory.selected_item == item_id:
			btn.modulate = Color.YELLOW
		btn.pressed.connect(_on_item_pressed.bind(item_id))
		item_list.add_child(btn)

func _on_item_pressed(item_id: String) -> void:
	if Inventory.selected_item == item_id:
		Inventory.clear_selection()
	else:
		Inventory.select_item(item_id)
	_refresh()
