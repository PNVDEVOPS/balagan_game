extends CanvasLayer

signal note_closed()

# Конфигурация для каждого типа записки
const CONFIGS: Dictionary = {
	"mother": {
		"texture":   "res://assets/ui/notes/note_mother.png",
		"font":      "res://assets/fonts/Caveat-Regular.ttf",
		"font_size": 14,
		"ink":       Color(0.12, 0.07, 0.04),
	},
	"father": {
		"texture":   "res://assets/ui/notes/note_father.png",
		"font":      "res://assets/fonts/SegoeScript.ttf",
		"font_size": 11,
		"ink":       Color(0.08, 0.07, 0.10),
	},
	"kydaana": {
		"texture":   "res://assets/ui/notes/note_kydaana.png",
		"font":      "res://assets/fonts/PlaypenSans-Regular.ttf",
		"font_size": 12,
		"ink":       Color(0.10, 0.10, 0.05),
	},
}

var _lines: Array = []
var _index: int = 0
var _is_open: bool = false
var is_open: bool:
	get: return _is_open

var _overlay:  ColorRect
var _panel:    PanelContainer
var _speaker:  Label
var _text:     RichTextLabel
var _hint:     Label

func _ready() -> void:
	layer = 15
	_build_ui()
	_overlay.visible = false
	# Когда записка закрыта — сообщаем DialogueManager
	note_closed.connect(func():
		DialogueManager.is_active = false
		DialogueManager.dialogue_finished.emit()
	)

func open(lines: Array, note_type: String) -> void:
	_lines = lines
	_index = 0
	_is_open = true
	_apply_style(CONFIGS.get(note_type, CONFIGS["mother"]))
	_show_line()
	_overlay.visible = true

func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_click)
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(400, 180)
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left",   26)
	margin.add_theme_constant_override("margin_right",  26)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 9)
	_speaker.uppercase = true
	vbox.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.custom_minimum_size = Vector2(340, 100)
	_text.fit_content = true
	_text.scroll_active = false
	_text.layout_mode = 2
	_text.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_text)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(_hint)

func _apply_style(cfg: Dictionary) -> void:
	# Фон-бумага
	var sbox := StyleBoxTexture.new()
	if ResourceLoader.exists(cfg["texture"]):
		sbox.texture = load(cfg["texture"])
	sbox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	sbox.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	_panel.add_theme_stylebox_override("panel", sbox)

	# Шрифт чернилами
	var ink: Color = cfg["ink"]
	_text.add_theme_color_override("default_color", ink)
	_text.add_theme_font_size_override("normal_font_size", cfg["font_size"])
	if ResourceLoader.exists(cfg["font"]):
		var fnt := load(cfg["font"]) as Font
		if fnt:
			_text.add_theme_font_override("normal_font", fnt)

	var dim := Color(ink.r, ink.g, ink.b, 0.55)
	_speaker.modulate = dim
	_hint.modulate    = dim

func _show_line() -> void:
	if _index >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_index]
	_speaker.text   = line.get("speaker", "")
	_speaker.visible = not _speaker.text.is_empty()
	_text.text      = line.get("text", "")
	_hint.text = "[E] закрыть" if _index >= _lines.size() - 1 else "[E] далее"

func _advance() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()

func _close() -> void:
	_is_open = false
	_overlay.visible = false
	note_closed.emit()

func _on_click(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("advance_dialogue") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
