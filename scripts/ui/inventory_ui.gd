extends CanvasLayer

const SLOT_COUNT := 6

const ITEM_COMMENTS: Dictionary = {
	"flashlight": "Фонарик. Аккумулятор заряжен — пока выручает.",
	"oil_lamp": "Масляная лампа. Настоящий огонь — там, где фонарь бессилен.",
}

const ITEM_NAMES: Dictionary = {
	"flashlight": "Фонарик",
	"oil_lamp": "Лампа",
}

# Иконки предметов в ячейках (рисуются 1:1, с сохранением пропорций)
const ITEM_ICONS: Dictionary = {
	"flashlight": "res://assets/sprites/items/flashlight_hand.png",
	"oil_lamp":   "res://assets/sprites/items/lamp_hand.png",
}

@onready var inventory_panel: PanelContainer = $InventoryPanel
@onready var bag_button: Button = $BagButton
@onready var slots_row: HBoxContainer = $InventoryPanel/SlotsRow

var is_open: bool = false
var _slots: Array[Button] = []
var _icons: Array[TextureRect] = []

func _ready() -> void:
	_apply_panel_style()
	Inventory.inventory_changed.connect(_refresh)
	bag_button.pressed.connect(toggle)
	_build_slots()

func _apply_panel_style() -> void:
	# Общий фон не нужен — только сами слоты имеют оформление
	inventory_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active:
		return
	if event.is_action_pressed("inventory"):
		toggle()

func _build_slots() -> void:
	var slot_tex := load("res://assets/ui/inv_slot.png") as Texture2D
	for i in SLOT_COUNT:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(30, 30)   # квадрат 1:1
		slot.focus_mode = Control.FOCUS_NONE
		slot.flat = false
		slot.clip_text = true
		slot.add_theme_font_size_override("font_size", 8)
		if slot_tex:
			var style := StyleBoxTexture.new()
			style.texture = slot_tex
			style.texture_margin_left   = 5
			style.texture_margin_right  = 5
			style.texture_margin_top    = 5
			style.texture_margin_bottom = 5
			slot.add_theme_stylebox_override("normal",   style)
			slot.add_theme_stylebox_override("disabled", style)
			slot.add_theme_stylebox_override("hover",    style)
			slot.add_theme_stylebox_override("pressed",  style)
		# Иконка предмета поверх ячейки, с сохранением пропорций (1:1)
		var icon := TextureRect.new()
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 4.0
		icon.offset_top = 4.0
		icon.offset_right = -4.0
		icon.offset_bottom = -4.0
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_icons.append(icon)
		slot.pressed.connect(_on_slot_pressed.bind(i))
		slots_row.add_child(slot)
		_slots.append(slot)

func toggle() -> void:
	is_open = not is_open
	inventory_panel.visible = is_open
	_refresh()

func _refresh() -> void:
	for i in _slots.size():
		var slot: Button = _slots[i]
		var icon: TextureRect = _icons[i]
		if i < Inventory.items.size():
			var item_id: String = Inventory.items[i]
			var tex_path: String = ITEM_ICONS.get(item_id, "")
			if tex_path != "" and ResourceLoader.exists(tex_path):
				icon.texture = load(tex_path)
				slot.text = ""                       # есть иконка — текст не нужен
			else:
				icon.texture = null
				slot.text = ITEM_NAMES.get(item_id, item_id)
			slot.modulate = Color.WHITE
			slot.disabled = false
		else:
			icon.texture = null
			slot.text = ""
			slot.modulate = Color(0.35, 0.35, 0.4, 0.8)
			slot.disabled = true

func _on_slot_pressed(index: int) -> void:
	if index >= Inventory.items.size():
		return
	var item_id := Inventory.items[index]
	var comment: String = ITEM_COMMENTS.get(item_id, "...")
	DialogueManager.show_text("", comment)
