extends CanvasLayer

enum Pos {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	MID_LEFT, MID_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT
}

const ANCHORS: Dictionary = {
	Pos.TOP_LEFT:      Vector2(0.10, 0.10),
	Pos.TOP_CENTER:    Vector2(0.50, 0.08),
	Pos.TOP_RIGHT:     Vector2(0.85, 0.10),
	Pos.MID_LEFT:      Vector2(0.08, 0.50),
	Pos.MID_RIGHT:     Vector2(0.82, 0.50),
	Pos.BOTTOM_LEFT:   Vector2(0.10, 0.85),
	Pos.BOTTOM_CENTER: Vector2(0.50, 0.88),
	Pos.BOTTOM_RIGHT:  Vector2(0.85, 0.85),
}

const COOLDOWN: float = 90.0

var _cooldown_timer: float = 0.0
var _label: Label = null

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.90, 1.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.size = Vector2(260, 60)
	_label.modulate.a = 0.0
	add_child(_label)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func show_subtitle(text: String, pos: Pos) -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = COOLDOWN
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var anchor: Vector2 = ANCHORS[pos]
	_label.text = text
	_label.position = anchor * vp - _label.size * 0.5
	_label.modulate.a = 0.0
	var hang: float = clampf(text.length() * 0.06, 3.0, 5.0)
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hang)
	tw.tween_property(_label, "modulate:a", 0.0, 1.2)

func show_subtitle_pair(text1: String, pos1: Pos, delay: float, text2: String, pos2: Pos) -> void:
	show_subtitle(text1, pos1)
	await get_tree().create_timer(delay + 0.8).timeout
	_cooldown_timer = 0.0
	show_subtitle(text2, pos2)
