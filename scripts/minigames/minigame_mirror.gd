class_name MinigameMirror
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const SHARD_COUNT: int = 7
const SNAP_DISTANCE: float = 48.0
# Shard slot positions relative to mirror frame center (pixels)
const SLOT_OFFSETS: Array[Vector2] = [
	Vector2(-80.0, -100.0),
	Vector2(20.0, -110.0),
	Vector2(95.0, -60.0),
	Vector2(90.0, 40.0),
	Vector2(10.0, 100.0),
	Vector2(-85.0, 70.0),
	Vector2(-50.0, 0.0)
]
# Starting scatter offsets for shards (so they begin displaced from their slots)
const SCATTER_OFFSETS: Array[Vector2] = [
	Vector2(-220.0, 80.0),
	Vector2(200.0, -140.0),
	Vector2(-180.0, -120.0),
	Vector2(220.0, 100.0),
	Vector2(-160.0, 130.0),
	Vector2(180.0, 60.0),
	Vector2(0.0, 160.0)
]
const SHARD_COLORS: Array[Color] = [
	Color(0.6, 0.7, 0.85),
	Color(0.55, 0.65, 0.8),
	Color(0.65, 0.75, 0.9),
	Color(0.5, 0.6, 0.78),
	Color(0.7, 0.78, 0.9),
	Color(0.58, 0.68, 0.82),
	Color(0.62, 0.72, 0.87)
]

var _placed_count: int = 0
var _dragging_shard: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _can_interact: bool = true
var _frame_center: Vector2 = Vector2.ZERO

var _slots: Array[Control] = []
var _shards: Array[Control] = []

func _ready() -> void:
	layer = 10
	_build_ui()

func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.9)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = "Собери зеркало"
	title.add_theme_font_size_override("font_size", 22)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-150.0, 50.0)
	title.size = Vector2(300.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Hint
	var hint := Label.new()
	hint.text = "Перетащи осколки на своё место"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position = Vector2(-150.0, 90.0)
	hint.size = Vector2(300.0, 30.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	var vp_size := get_viewport().get_visible_rect().size
	_frame_center = vp_size * 0.5

	# Mirror frame (oval outline)
	var frame := ColorRect.new()
	frame.color = Color(0.3, 0.25, 0.2, 0.8)
	frame.size = Vector2(240.0, 280.0)
	frame.position = _frame_center - frame.size * 0.5
	add_child(frame)

	# Slot markers inside the frame
	_slots.clear()
	for i in range(SHARD_COUNT):
		var slot := ColorRect.new()
		slot.color = Color(0.15, 0.12, 0.1, 0.6)
		slot.size = Vector2(36.0, 36.0)
		slot.position = _frame_center + SLOT_OFFSETS[i] - slot.size * 0.5
		add_child(slot)
		_slots.append(slot)

	# Shard pieces (scattered, draggable)
	_shards.clear()
	for i in range(SHARD_COUNT):
		var shard := ColorRect.new()
		shard.color = SHARD_COLORS[i]
		shard.size = Vector2(40.0, 40.0)
		shard.position = _frame_center + SLOT_OFFSETS[i] + SCATTER_OFFSETS[i] - shard.size * 0.5
		shard.set_meta("target_slot_index", i)
		shard.set_meta("is_placed", false)
		shard.mouse_filter = Control.MOUSE_FILTER_STOP
		shard.gui_input.connect(_on_shard_input.bind(shard))
		add_child(shard)
		_shards.append(shard)

	# Reveal panel (hidden until solved)
	var reveal := Panel.new()
	reveal.name = "RevealPanel"
	reveal.visible = false
	reveal.size = Vector2(400.0, 140.0)
	reveal.position = _frame_center - reveal.size * 0.5 + Vector2(0.0, 180.0)
	add_child(reveal)

	var reveal_label := Label.new()
	reveal_label.text = "В отражении видно: третья доска от окна, где сучок похож на звезду."
	reveal_label.add_theme_font_size_override("font_size", 16)
	reveal_label.position = Vector2(12.0, 12.0)
	reveal_label.size = Vector2(376.0, 116.0)
	reveal_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	reveal.add_child(reveal_label)

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Закрыть [ESC]"
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_btn.position = Vector2(-180.0, -70.0)
	close_btn.size = Vector2(160.0, 40.0)
	close_btn.pressed.connect(_on_close_pressed)
	add_child(close_btn)

func _on_shard_input(event: InputEvent, shard: Control) -> void:
	if not _can_interact:
		return
	if shard.get_meta("is_placed", false):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging_shard = shard
				_drag_offset = shard.position - get_viewport().get_mouse_position()
			else:
				if _dragging_shard == shard:
					_try_snap_shard(shard)
					_dragging_shard = null

func _process(_delta: float) -> void:
	if _dragging_shard:
		_dragging_shard.position = get_viewport().get_mouse_position() + _drag_offset

func _try_snap_shard(shard: Control) -> void:
	var target_index: int = shard.get_meta("target_slot_index", -1)
	if target_index < 0 or target_index >= _slots.size():
		return
	var slot: Control = _slots[target_index]
	var shard_center: Vector2 = shard.position + shard.size * 0.5
	var slot_center: Vector2 = slot.position + slot.size * 0.5
	if shard_center.distance_to(slot_center) <= SNAP_DISTANCE:
		shard.position = slot.position + (slot.size - shard.size) * 0.5
		shard.set_meta("is_placed", true)
		shard.color = shard.color.lightened(0.3)
		_placed_count += 1
		_check_solved()

func _check_solved() -> void:
	if _placed_count >= SHARD_COUNT:
		_on_solved()

func _on_solved() -> void:
	_can_interact = false
	var close_btn := get_node_or_null("CloseBtn")
	if close_btn:
		close_btn.disabled = true
	# Healing animation
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.3, 2.0), 0.6)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.7)
	await tween.finished
	await get_tree().create_timer(0.4).timeout
	# Show floorboard hint
	var reveal := get_node_or_null("RevealPanel")
	if reveal:
		reveal.visible = true
	await get_tree().create_timer(3.5).timeout
	minigame_completed.emit("mirror")
	queue_free()

func _on_close_pressed() -> void:
	minigame_cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
