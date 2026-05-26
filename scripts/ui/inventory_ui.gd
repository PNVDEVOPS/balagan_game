extends CanvasLayer

const SLOT_COUNT := 6

const ITEM_COMMENTS: Dictionary = {
	"flashlight": "Фонарик. Аккумулятор заряжен — пока выручает.",
}

@onready var inventory_bar: HBoxContainer = $InventoryBar
@onready var bag_button: Button = $InventoryBar/BagButton
@onready var slots_row: HBoxContainer = $InventoryBar/SlotsRow

var is_open: bool = false
var _slots: Array[Button] = []

func _ready() -> void:
	Inventory.inventory_changed.connect(_refresh)
	bag_button.pressed.connect(toggle)
	_build_slots()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()

func _build_slots() -> void:
	for i in SLOT_COUNT:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(28, 22)
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = true
		slot.add_theme_font_size_override("font_size", 8)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slots_row.add_child(slot)
		_slots.append(slot)

func toggle() -> void:
	is_open = not is_open
	slots_row.visible = is_open
	inventory_bar.modulate.a = 0.92 if is_open else 0.6
	_refresh()

func _refresh() -> void:
	for i in _slots.size():
		var slot: Button = _slots[i]
		if i < Inventory.items.size():
			slot.text = Inventory.items[i]
			slot.modulate = Color.WHITE
			slot.disabled = false
		else:
			slot.text = ""
			slot.modulate = Color(0.35, 0.35, 0.4, 0.8)
			slot.disabled = true

func _on_slot_pressed(index: int) -> void:
	if index >= Inventory.items.size():
		return
	var item_id := Inventory.items[index]
	var comment: String = ITEM_COMMENTS.get(item_id, "...")
	DialogueManager.show_text("", comment)
