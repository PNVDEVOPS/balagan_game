extends CanvasLayer

signal window_closed

@onready var overlay: ColorRect = $Overlay
@onready var view_rect: ColorRect = $Panel/Margin/VBox/ViewRect
@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var description_label: RichTextLabel = $Panel/Margin/VBox/DescriptionLabel
@onready var silhouette: ColorRect = $Silhouette

var _ready_to_close: bool = false
var _jumpscare: bool = false
var _jumpscare_done: bool = false

func _ready() -> void:
	silhouette.modulate.a = 0.0
	overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)
	await tween.finished
	_ready_to_close = true

func open(p_title: String, p_description: String, p_view_color: Color = Color(0.06, 0.05, 0.07, 1.0)) -> void:
	title_label.text = p_title
	description_label.text = p_description
	view_rect.color = p_view_color

func open_jumpscare(p_title: String, p_description: String, p_view_color: Color = Color(0.04, 0.06, 0.1, 1.0)) -> void:
	open(p_title, p_description, p_view_color)
	_jumpscare = true

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_close:
		return
	var pressed := (event is InputEventKey and event.pressed) or \
				   (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	get_viewport().set_input_as_handled()

	if _jumpscare and not _jumpscare_done:
		_jumpscare_done = true
		_trigger_silhouette()
	else:
		_close()

func _trigger_silhouette() -> void:
	silhouette.modulate.a = 0.0
	silhouette.visible = true
	var tw := create_tween()
	tw.tween_property(silhouette, "modulate:a", 1.0, 0.05)
	tw.tween_interval(0.08)
	tw.tween_property(silhouette, "modulate:a", 0.0, 0.12)
	await tw.finished
	_close()

func _close() -> void:
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	await tw.finished
	window_closed.emit()
	queue_free()
