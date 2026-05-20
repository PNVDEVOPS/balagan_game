class_name MinigameCradle
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const GRID_SIZE: int = 4
const TILE_PX: int = 88
const TILE_GAP: int = 6
const SYMBOLS: Array[String] = [
	"❄", "✦", "◈", "⬡",
	"◉", "✧", "⬢", "◆",
	"✶", "◇", "⬟", "★",
	"❋", "⟡", "⊕", ""
]
# solved_state[grid_pos] = symbol index (-1 = blank)
# Blank is at index 15 (bottom-right) when solved
const SOLVED_STATE: Array[int] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,-1]

var _tiles: Array[int] = []
var _blank_pos: int = 15
var _tile_buttons: Array = []
var _can_interact: bool = true

func _ready() -> void:
	layer = 10
	_shuffle_tiles()
	_build_ui()

func _shuffle_tiles() -> void:
	_tiles.clear()
	for i in range(GRID_SIZE * GRID_SIZE - 1):
		_tiles.append(i)
	_tiles.append(-1)
	_blank_pos = GRID_SIZE * GRID_SIZE - 1

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(300):
		var neighbors := _get_adjacent_to_blank()
		var pick: int = neighbors[rng.randi() % neighbors.size()]
		_swap_with_blank(pick)

func _build_ui() -> void:
	# Dark overlay
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	# Title
	var title := Label.new()
	title.text = "Расставь символы по порядку"
	title.add_theme_font_size_override("font_size", 20)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200.0, 60.0)
	title.size = Vector2(400.0, 40.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Grid container
	var grid := GridContainer.new()
	grid.columns = GRID_SIZE
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	var total := GRID_SIZE * (TILE_PX + TILE_GAP) - TILE_GAP
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.position = Vector2(-total / 2.0, -total / 2.0)
	add_child(grid)

	_tile_buttons.clear()
	for pos in range(GRID_SIZE * GRID_SIZE):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(TILE_PX, TILE_PX)
		btn.add_theme_font_size_override("font_size", 26)
		var sym_idx: int = _tiles[pos]
		btn.text = SYMBOLS[sym_idx] if sym_idx >= 0 else ""
		btn.disabled = (sym_idx == -1)
		btn.pressed.connect(_on_tile_pressed.bind(pos))
		grid.add_child(btn)
		_tile_buttons.append(btn)

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Закрыть [ESC]"
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_btn.position = Vector2(-180.0, -70.0)
	close_btn.size = Vector2(160.0, 40.0)
	close_btn.pressed.connect(_on_close_pressed)
	add_child(close_btn)

func _on_tile_pressed(pos: int) -> void:
	if not _can_interact:
		return
	if not _is_adjacent_to_blank(pos):
		return
	_swap_with_blank(pos)
	_refresh_grid()
	if _check_solved():
		_on_solved()

func _is_adjacent_to_blank(pos: int) -> bool:
	return pos in _get_adjacent_to_blank()

func _get_adjacent_to_blank() -> Array[int]:
	var result: Array[int] = []
	var row: int = _blank_pos / GRID_SIZE
	var col: int = _blank_pos % GRID_SIZE
	if row > 0:
		result.append(_blank_pos - GRID_SIZE)
	if row < GRID_SIZE - 1:
		result.append(_blank_pos + GRID_SIZE)
	if col > 0:
		result.append(_blank_pos - 1)
	if col < GRID_SIZE - 1:
		result.append(_blank_pos + 1)
	return result

func _swap_with_blank(pos: int) -> void:
	_tiles[_blank_pos] = _tiles[pos]
	_tiles[pos] = -1
	_blank_pos = pos

func _refresh_grid() -> void:
	for pos in range(_tile_buttons.size()):
		var btn: Button = _tile_buttons[pos]
		var sym_idx: int = _tiles[pos]
		btn.text = SYMBOLS[sym_idx] if sym_idx >= 0 else ""
		btn.disabled = (sym_idx == -1)

func _check_solved() -> bool:
	for i in range(_tiles.size()):
		if _tiles[i] != SOLVED_STATE[i]:
			return false
	return true

func _on_solved() -> void:
	_can_interact = false
	var close_btn := get_node_or_null("CloseBtn")
	if close_btn:
		close_btn.disabled = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.8), 0.4)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	await tween.finished
	await get_tree().create_timer(0.6).timeout
	minigame_completed.emit("cradle")
	queue_free()

func _on_close_pressed() -> void:
	minigame_cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()
