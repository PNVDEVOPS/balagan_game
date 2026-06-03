extends CanvasLayer

@onready var bg_panel: PanelContainer = $BgPanel
@onready var item_sprite: TextureRect = $BgPanel/VBoxContainer/ItemSprite
@onready var name_label: Label = $BgPanel/VBoxContainer/ItemNameLabel
@onready var desc_label: RichTextLabel = $BgPanel/VBoxContainer/ItemDescLabel

var _auto_close_timer: float = 0.0
var _queued_name: String = ""
var _queued_desc: String = ""
var _queued_tex: Texture2D = null
var _has_queued: bool = false

func _ready() -> void:
	_apply_panel_style()
	bg_panel.visible = false

func _apply_panel_style() -> void:
	var tex := load("res://assets/ui/panel_9slice.png") as Texture2D
	if not tex:
		return
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 16.0
	style.texture_margin_right = 16.0
	style.texture_margin_top = 16.0
	style.texture_margin_bottom = 16.0
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	bg_panel.add_theme_stylebox_override("panel", style)

func show_item(p_item_name: String, p_description: String, p_texture: Texture2D = null) -> void:
	_queued_name = p_item_name
	_queued_desc = p_description
	_queued_tex = p_texture
	_has_queued = true

func _show_now(p_item_name: String, p_description: String, p_texture: Texture2D = null) -> void:
	item_sprite.texture = p_texture
	item_sprite.visible = p_texture != null
	name_label.text = p_item_name
	desc_label.text = p_description
	bg_panel.modulate.a = 0.0
	bg_panel.visible = true
	var tween := create_tween()
	tween.tween_property(bg_panel, "modulate:a", 1.0, 0.3)
	_auto_close_timer = 4.0

func _process(delta: float) -> void:
	if _has_queued and not DialogueManager.is_active:
		_has_queued = false
		_show_now(_queued_name, _queued_desc, _queued_tex)
	if not bg_panel.visible:
		return
	_auto_close_timer -= delta
	if _auto_close_timer <= 0.0:
		_close()

func _unhandled_input(event: InputEvent) -> void:
	if not bg_panel.visible:
		return
	if event.is_action_pressed("advance_dialogue") or event.is_action_pressed("ui_accept"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	var tween := create_tween()
	tween.tween_property(bg_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): bg_panel.visible = false; bg_panel.modulate.a = 1.0)
