extends CanvasLayer

const NOTE_ORDER: Array[String] = [
	"note_kydaana_1", "note_kydaana_2", "note_kydaana_3",
	"note_kydaana_4", "note_kydaana_5",
	"note_mother_1", "note_mother_2", "note_mother_3", "note_mother_4",
	"note_father_1", "note_father_2", "note_father_3", "note_father_4",
	"note_env_4", "note_env_5",
	"artifact_amulet", "artifact_doll", "artifact_earring",
	"riddle_kamyolk", "riddle_cradle", "riddle_mirror",
	"poem_ritual",
]

# Единая иконка-письмо для кнопки журнала и для ячеек записок
const TEX_LETTER := preload("res://assets/ui/inv_letter.png")

var _journal_btn: Button
var _panel:       PanelContainer
var _grid:        GridContainer

func _ready() -> void:
	layer = 5
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	_journal_btn = Button.new()
	_journal_btn.offset_left   = 4.0
	_journal_btn.offset_top    = 3.0
	_journal_btn.offset_right  = 26.0
	_journal_btn.offset_bottom = 25.0
	_journal_btn.custom_minimum_size = Vector2(22, 22)
	_journal_btn.focus_mode = Control.FOCUS_NONE
	_journal_btn.flat = true
	_journal_btn.expand_icon = true
	_journal_btn.icon = TEX_LETTER
	_journal_btn.pressed.connect(toggle)
	add_child(_journal_btn)

	_panel = PanelContainer.new()
	_panel.offset_left = 4.0
	_panel.offset_top  = 30.0
	_panel.custom_minimum_size = Vector2(290, 0)
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color            = Color(0.08, 0.06, 0.04, 0.95)
	panel_bg.border_width_left   = 1
	panel_bg.border_width_right  = 1
	panel_bg.border_width_top    = 1
	panel_bg.border_width_bottom = 1
	panel_bg.border_color        = Color(0.28, 0.20, 0.12, 0.9)
	_panel.add_theme_stylebox_override("panel", panel_bg)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var title_row := HBoxContainer.new()
	title_row.layout_mode = 2
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Записки"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(func(): _panel.visible = false)
	title_row.add_child(close_btn)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.layout_mode = 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)

func toggle() -> void:
	if DialogueManager.is_active:
		return
	if _panel.visible:
		_panel.visible = false
	else:
		_rebuild_grid()
		_panel.visible = true

func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var num := 1
	for note_id: String in NOTE_ORDER:
		if GameManager.notes_found.has(note_id):
			_add_entry(num, note_id)
			num += 1

func _add_entry(num: int, note_id: String) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(50, 50)   # квадратная ячейка 1:1
	btn.flat = true
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE

	var tex := TextureRect.new()
	tex.texture = TEX_LETTER
	# Иконка-письмо целиком, с сохранением пропорций (не обрезок)
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.layout_mode = 1
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex)

	var lbl := Label.new()
	lbl.text = str(num)
	lbl.layout_mode = 1
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left   = -16.0
	lbl.offset_top    = -14.0
	lbl.offset_right  = -2.0
	lbl.offset_bottom = -2.0
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	btn.pressed.connect(func():
		_panel.visible = false
		DialogueManager.start_dialogue("notes/" + note_id)
	)
	_grid.add_child(btn)

func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		_panel.visible = false
		get_viewport().set_input_as_handled()
