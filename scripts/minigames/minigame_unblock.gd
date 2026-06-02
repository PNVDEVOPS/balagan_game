class_name MinigameUnblock
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const GRID_COLS := 6
const GRID_ROWS := 6
const EXIT_ROW := 2
const CELL := 80

# [row, col, is_horizontal, length, is_amulet]
const LAYOUT: Array = [
	[2, 0, true,  2, true],
	[1, 2, false, 2, false],
	[1, 3, false, 2, false],
	[0, 2, true,  3, false],
	[2, 4, false, 2, false],
	[0, 5, false, 2, false],
	[4, 0, true,  2, false],
]

const COLOR_WOOD   := Color(0.45, 0.28, 0.12)
const COLOR_AMULET := Color(0.85, 0.65, 0.10)
const COLOR_SELECT := Color(1.0, 1.0, 1.0, 0.35)
const COLOR_BG     := Color(0.10, 0.07, 0.04)
const COLOR_GRID   := Color(0.06, 0.04, 0.02)
const COLOR_EXIT   := Color(0.85, 0.65, 0.10, 0.25)

var _blocks: Array = []
var _selected: int = -1
var _can_interact: bool = true
var _grid_ctrl: Control

func _ready() -> void:
	layer = 10
	for entry in LAYOUT:
		_blocks.append({r = entry[0], c = entry[1], horiz = entry[2], len = entry[3], amulet = entry[4]})
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title := Label.new()
	title.text = "Разгреби дрова — освободи путь"
	title.add_theme_font_size_override("font_size", 18)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200.0, 50.0)
	title.size = Vector2(400.0, 36.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var grid_size := float(CELL * GRID_COLS)
	_grid_ctrl = Control.new()
	_grid_ctrl.name = "GridCtrl"
	_grid_ctrl.set_anchors_preset(Control.PRESET_CENTER)
	_grid_ctrl.position = Vector2(-grid_size / 2.0, -grid_size / 2.0)
	_grid_ctrl.size = Vector2(grid_size, grid_size)
	_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_ctrl.draw.connect(_on_grid_draw)
	_grid_ctrl.gui_input.connect(_on_grid_input)
	add_child(_grid_ctrl)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Закрыть [ESC]"
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_btn.position = Vector2(-180.0, -70.0)
	close_btn.size = Vector2(160.0, 40.0)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)

func _on_grid_draw() -> void:
	_grid_ctrl.draw_rect(Rect2(Vector2.ZERO, _grid_ctrl.size), COLOR_BG)
	for i in range(GRID_COLS + 1):
		var x := float(i * CELL)
		_grid_ctrl.draw_line(Vector2(x, 0), Vector2(x, _grid_ctrl.size.y), COLOR_GRID, 1.0)
	for i in range(GRID_ROWS + 1):
		var y := float(i * CELL)
		_grid_ctrl.draw_line(Vector2(0, y), Vector2(_grid_ctrl.size.x, y), COLOR_GRID, 1.0)
	var ey := EXIT_ROW * CELL
	_grid_ctrl.draw_rect(Rect2(Vector2(_grid_ctrl.size.x - 4, ey + 6), Vector2(6, CELL - 12)), COLOR_EXIT)
	for i in range(_blocks.size()):
		var b: Dictionary = _blocks[i]
		var rect := _block_rect(b)
		var col := COLOR_AMULET if b.amulet else COLOR_WOOD
		_grid_ctrl.draw_rect(rect.grow(-4), col)
		if i == _selected:
			_grid_ctrl.draw_rect(rect.grow(-4), COLOR_SELECT)
		_grid_ctrl.draw_rect(rect.grow(-4), Color(0, 0, 0, 0.4), false, 2.0)

func _block_rect(b: Dictionary) -> Rect2:
	var w := float(CELL * b.len) if b.horiz else float(CELL)
	var h := float(CELL) if b.horiz else float(CELL * b.len)
	return Rect2(float(b.c * CELL), float(b.r * CELL), w, h)

func _on_grid_input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var col := int(event.position.x / CELL)
	var row := int(event.position.y / CELL)
	col = clampi(col, 0, GRID_COLS - 1)
	row = clampi(row, 0, GRID_ROWS - 1)
	if _selected >= 0 and _try_slide_to(_selected, row, col):
		return
	_selected = _find_block_at(row, col)
	_grid_ctrl.queue_redraw()

func _find_block_at(row: int, col: int) -> int:
	for i in range(_blocks.size()):
		if _cell_in_block(row, col, _blocks[i]):
			return i
	return -1

func _cell_in_block(row: int, col: int, b: Dictionary) -> bool:
	if b.horiz:
		return row == b.r and col >= b.c and col < b.c + b.len
	else:
		return col == b.c and row >= b.r and row < b.r + b.len

func _try_slide_to(idx: int, tr: int, tc: int) -> bool:
	var b: Dictionary = _blocks[idx]
	if b.horiz:
		if tr != b.r:
			_selected = -1
			_grid_ctrl.queue_redraw()
			return false
		if tc >= b.c and tc < b.c + b.len:
			return false
		var new_c := tc if tc < b.c else tc - b.len + 1
		new_c = clampi(new_c, 0, GRID_COLS - b.len)
		if not _can_slide_h(idx, new_c):
			return false
		_blocks[idx].c = new_c
	else:
		if tc != b.c:
			_selected = -1
			_grid_ctrl.queue_redraw()
			return false
		if tr >= b.r and tr < b.r + b.len:
			return false
		var new_r := tr if tr < b.r else tr - b.len + 1
		new_r = clampi(new_r, 0, GRID_ROWS - b.len)
		if not _can_slide_v(idx, new_r):
			return false
		_blocks[idx].r = new_r
	_grid_ctrl.queue_redraw()
	_check_win()
	return true

func _can_slide_h(idx: int, new_c: int) -> bool:
	var b: Dictionary = _blocks[idx]
	var lo := mini(b.c, new_c)
	var hi := maxi(b.c + b.len - 1, new_c + b.len - 1)
	for i in range(_blocks.size()):
		if i == idx:
			continue
		for dc in range(lo, hi + 1):
			if _cell_in_block(b.r, dc, _blocks[i]):
				return false
	return true

func _can_slide_v(idx: int, new_r: int) -> bool:
	var b: Dictionary = _blocks[idx]
	var lo := mini(b.r, new_r)
	var hi := maxi(b.r + b.len - 1, new_r + b.len - 1)
	for i in range(_blocks.size()):
		if i == idx:
			continue
		for dr in range(lo, hi + 1):
			if _cell_in_block(dr, b.c, _blocks[i]):
				return false
	return true

func _check_win() -> void:
	for i in range(_blocks.size()):
		var b: Dictionary = _blocks[i]
		if b.amulet and b.r == EXIT_ROW and b.c + b.len >= GRID_COLS:
			_on_solved()
			return

func _on_solved() -> void:
	_can_interact = false
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.4, 1.4, 0.8), 0.4)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	await tw.finished
	await get_tree().create_timer(0.5).timeout
	minigame_completed.emit("unblock")
	queue_free()

func _on_close() -> void:
	minigame_cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
		return
	if _selected < 0:
		return
	var b: Dictionary = _blocks[_selected]
	var moved := false
	if b.horiz:
		if event.is_action_pressed("ui_left") and b.c > 0 and _can_slide_h(_selected, b.c - 1):
			_blocks[_selected].c -= 1
			moved = true
		elif event.is_action_pressed("ui_right") and b.c + b.len < GRID_COLS and _can_slide_h(_selected, b.c + 1):
			_blocks[_selected].c += 1
			moved = true
	else:
		if event.is_action_pressed("ui_up") and b.r > 0 and _can_slide_v(_selected, b.r - 1):
			_blocks[_selected].r -= 1
			moved = true
		elif event.is_action_pressed("ui_down") and b.r + b.len < GRID_ROWS and _can_slide_v(_selected, b.r + 1):
			_blocks[_selected].r += 1
			moved = true
	if moved:
		_check_win()
		_grid_ctrl.queue_redraw()
		get_viewport().set_input_as_handled()
