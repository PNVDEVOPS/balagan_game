extends CanvasLayer

@onready var container: HBoxContainer       = $Container
@onready var avatar_panel: PanelContainer   = $Container/AvatarPanel
@onready var avatar_rect: TextureRect       = $Container/AvatarPanel/AvatarRect
@onready var text_panel: PanelContainer     = $Container/TextPanel
@onready var speaker_label: Label           = $Container/TextPanel/Content/SpeakerLabel
@onready var text_label: RichTextLabel      = $Container/TextPanel/Content/TextLabel

# Ключи — любые варианты написания имён персонажей (lower-case)
const AVATAR_TEXTURES: Dictionary = {
	"player":   "res://assets/ui/avatars/player.png",
	"ньургун":  "res://assets/ui/avatars/player.png",
	"лайка":    "res://assets/ui/avatars/laika.png",
	"laika":    "res://assets/ui/avatars/laika.png",
	"кыдаана":  "res://assets/ui/avatars/kydaana.png",
	"kydaana":  "res://assets/ui/avatars/kydaana.png",
}
# Аватар по умолчанию (когда speaker пустой — показываем игрока)
const DEFAULT_AVATAR := "res://assets/ui/avatars/player.png"

var full_text: String = ""
var char_index: int = 0
var typewriter_speed: float = 0.05
var is_typing: bool = false
var _type_timer: float = 0.0

func _ready() -> void:
	_apply_9slice(avatar_panel, 4.0, 4.0, 4.0, 4.0)
	_apply_9slice(text_panel,  10.0, 10.0, 8.0, 8.0)
	container.visible = false
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_line.connect(_on_dialogue_line)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

# texture_margin = 16 — соответствует тайлам 16px в текстуре 48x48
func _apply_9slice(node: PanelContainer,
		cm_l: float, cm_r: float, cm_t: float, cm_b: float) -> void:
	var tex := load("res://assets/ui/panel_9slice.png") as Texture2D
	if not tex:
		return
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left   = 16.0
	style.texture_margin_right  = 16.0
	style.texture_margin_top    = 16.0
	style.texture_margin_bottom = 16.0
	style.content_margin_left   = cm_l
	style.content_margin_right  = cm_r
	style.content_margin_top    = cm_t
	style.content_margin_bottom = cm_b
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	node.add_theme_stylebox_override("panel", style)

func _on_dialogue_started() -> void:
	container.visible = true

func _on_dialogue_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = not speaker.is_empty()
	_set_avatar(speaker)
	full_text = text
	text_label.text = ""
	char_index = 0
	_type_timer = 0.0
	is_typing = true
	_fit_height()

# Подгоняет высоту окна под содержимое. Максимум — 2 строки текста.
func _fit_height() -> void:
	await get_tree().process_frame
	var h := clampf(container.get_minimum_size().y, 70.0, 84.0)
	container.offset_top = -h - 3.0

func _set_avatar(speaker: String) -> void:
	var key  := speaker.to_lower().strip_edges()
	var path: String = AVATAR_TEXTURES.get(key, DEFAULT_AVATAR)
	if ResourceLoader.exists(path):
		avatar_rect.texture = load(path)
	else:
		avatar_rect.texture = null

func _on_dialogue_finished() -> void:
	container.visible = false
	is_typing = false

func _process(delta: float) -> void:
	if not is_typing:
		return
	_type_timer += delta
	var chars_to_add := int(_type_timer / typewriter_speed)
	if chars_to_add == 0:
		return
	_type_timer -= chars_to_add * typewriter_speed
	char_index += chars_to_add
	if char_index >= full_text.length():
		text_label.text = full_text
		is_typing = false
		return
	text_label.text = full_text.substr(0, char_index)

func _unhandled_input(event: InputEvent) -> void:
	if not container.visible:
		return
	if event.is_action_pressed("advance_dialogue"):
		if is_typing:
			text_label.text = full_text
			is_typing = false
		else:
			DialogueManager.advance()
		get_viewport().set_input_as_handled()
