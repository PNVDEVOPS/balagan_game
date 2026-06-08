class_name KlotskiPuzzle
extends CanvasLayer

signal puzzle_solved(moves: int)
signal puzzle_closed()

# ---- Цвета (меняй здесь) ----
const C_BG           := Color(0.08, 0.05, 0.03)
const C_GRID         := Color(0.16, 0.11, 0.06)
const C_CHEST        := Color(0.72, 0.55, 0.22)
const C_LOG_VERT     := Color(0.38, 0.23, 0.10)
const C_LOG_HORIZ    := Color(0.45, 0.28, 0.11)
const C_COAL         := Color(0.25, 0.19, 0.13)
const C_TARGET_FILL  := Color(0.65, 0.85, 1.0, 0.15)
const C_TARGET_EDGE  := Color(0.70, 0.88, 1.0, 0.60)
const C_SELECT       := Color(1.0, 1.0, 1.0, 0.22)
const C_PANEL_BG     := Color(0.06, 0.04, 0.02, 0.96)
const C_OVERLAY      := Color(0.0,  0.0,  0.0,  0.65)
const C_PIECE_EDGE   := Color(0.0,  0.0,  0.0,  0.35)
const C_TITLE        := Color(0.88, 0.72, 0.40)
const C_MOVES        := Color(0.70, 0.65, 0.55)

# ---- Размеры (меняй здесь) ----
# viewport 640x360: grid = 160x200, panel ~200x310
const CELL_SIZE   := 40
const TWEEN_SECS  := 0.12
const GRID_COLS   := 4
const GRID_ROWS   := 5
const WIN_COL     := 1
const WIN_ROW     := 3

# Раскладка: Huarong Dao без двух угольников (G, H убраны).
# Пустые клетки: (col1,row3), (col2,row3), (col1,row4), (col2,row4) — 4 свободных.
#   A B B C
#   A B B C
#   D E E F
#   D . . F
#   I . . J
const INITIAL_LAYOUT: Array = [
	["chest", 1, 0, 2, 2],  # шкатулка 2x2
	["v_A",   0, 0, 1, 2],
	["v_C",   3, 0, 1, 2],
	["v_D",   0, 2, 1, 2],
	["h_E",   1, 2, 2, 1],  # горизонтальное полено
	["v_F",   3, 2, 1, 2],
	["s_I",   0, 4, 1, 1],
	["s_J",   3, 4, 1, 1],
]

class Piece:
	var id: String
	var col: int
	var row: int
	var w: int
	var h: int

var _pieces: Array = []
var _moves: int = 0
var _can_interact: bool = true
var _selected: int = -1

var _drag_piece: int = -1
var _drag_axis: String = ""
var _drag_start_mouse: Vector2
var _drag_start_col: int
var _drag_start_row: int
var _is_dragging: bool = false
var _anim_offsets: Dictionary = {}
# Границы свободного скольжения (в пикселях, относительно старта) — чтобы при
# перетаскивании фигура не «проезжала» сквозь соседей/стены.
var _drag_lo: float = 0.0
var _drag_hi: float = 0.0

var _grid_ctrl: Control
var _moves_label: Label
var _tween: Tween

# ---- Текстуры фигур ----
const TEX_CHEST_PATH := "res://assets/sprites/items/chest.png"   # шкатулка
const TEX_LOGS_PATH  := "res://assets/sprites/items/logs.png"    # дрова (полено)
const TEX_COAL_PATH  := "res://assets/sprites/items/coal.png"    # уголёк
var _tex_chest: Texture2D = null
var _tex_logs:  Texture2D = null
var _tex_coal:  Texture2D = null

# ---- Публичный API ----

func open() -> void:
	_reset_board()
	show()

func close() -> void:
	puzzle_closed.emit()
	queue_free()

# ---- Инициализация ----

func _ready() -> void:
	layer = 20
	_load_textures()
	_build_ui()
	_reset_board()

func _load_textures() -> void:
	if ResourceLoader.exists(TEX_CHEST_PATH):
		_tex_chest = load(TEX_CHEST_PATH)
	if ResourceLoader.exists(TEX_LOGS_PATH):
		_tex_logs = load(TEX_LOGS_PATH)
	if ResourceLoader.exists(TEX_COAL_PATH):
		_tex_coal = load(TEX_COAL_PATH)

func _reset_board() -> void:
	if _tween:
		_tween.kill()
	_pieces.clear()
	_anim_offsets.clear()
	for entry: Array in INITIAL_LAYOUT:
		var p := Piece.new()
		p.id = entry[0]; p.col = entry[1]; p.row = entry[2]
		p.w  = entry[3]; p.h  = entry[4]
		_pieces.append(p)
	_moves        = 0
	_selected     = -1
	_can_interact = true
	_drag_piece   = -1
	_is_dragging  = false
	if _moves_label:
		_moves_label.text = "Ходы: 0"
	if _grid_ctrl:
		_grid_ctrl.queue_redraw()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var panel_w: int = CELL_SIZE * GRID_COLS + 40
	var panel_h: int = CELL_SIZE * GRID_ROWS + 110

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left   = -panel_w / 2.0
	panel.offset_right  =  panel_w / 2.0
	panel.offset_top    = -panel_h / 2.0
	panel.offset_bottom =  panel_h / 2.0
	var slice_tex := load("res://assets/ui/panel_9slice.png") as Texture2D
	var sbox: StyleBox
	if slice_tex:
		var st := StyleBoxTexture.new()
		st.texture = slice_tex
		st.texture_margin_left   = 16.0
		st.texture_margin_right  = 16.0
		st.texture_margin_top    = 16.0
		st.texture_margin_bottom = 16.0
		st.content_margin_left   = 8.0
		st.content_margin_right  = 8.0
		st.content_margin_top    = 6.0
		st.content_margin_bottom = 6.0
		st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		st.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sbox = st
	else:
		var sf := StyleBoxFlat.new()
		sf.bg_color = C_PANEL_BG
		sbox = sf
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var grid_wrap := CenterContainer.new()
	vbox.add_child(grid_wrap)

	_grid_ctrl = Control.new()
	_grid_ctrl.custom_minimum_size = Vector2(CELL_SIZE * GRID_COLS, CELL_SIZE * GRID_ROWS)
	_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_ctrl.draw.connect(_on_grid_draw)
	_grid_ctrl.gui_input.connect(_on_grid_input)
	grid_wrap.add_child(_grid_ctrl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var reset_btn := Button.new()
	reset_btn.text = "Заново"
	reset_btn.add_theme_font_size_override("font_size", 12)
	reset_btn.pressed.connect(_reset_board)
	hbox.add_child(reset_btn)

	var close_btn := Button.new()
	close_btn.text = "Выйти"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(close)
	hbox.add_child(close_btn)

# ---- Отрисовка ----

func _on_grid_draw() -> void:
	var gs := _grid_ctrl.custom_minimum_size
	_grid_ctrl.draw_rect(Rect2(Vector2.ZERO, gs), C_BG)

	# Целевая зона — куда нужно поставить шкатулку
	var tgt := Rect2(WIN_COL * CELL_SIZE, WIN_ROW * CELL_SIZE, 2 * CELL_SIZE, 2 * CELL_SIZE)
	_grid_ctrl.draw_rect(tgt, C_TARGET_FILL)
	_grid_ctrl.draw_rect(tgt, C_TARGET_EDGE, false, 2.0)

	# Сетка
	for i in GRID_COLS + 1:
		_grid_ctrl.draw_line(Vector2(i * CELL_SIZE, 0.0), Vector2(i * CELL_SIZE, gs.y), C_GRID)
	for i in GRID_ROWS + 1:
		_grid_ctrl.draw_line(Vector2(0.0, i * CELL_SIZE), Vector2(gs.x, i * CELL_SIZE), C_GRID)

	# Фигуры
	for i in _pieces.size():
		var p: Piece = _pieces[i]
		var off: Vector2 = _anim_offsets.get(i, Vector2.ZERO)
		var rect := Rect2(
			p.col * CELL_SIZE + off.x, p.row * CELL_SIZE + off.y,
			p.w * CELL_SIZE,           p.h * CELL_SIZE
		)
		var inner := rect.grow(-3.0)
		var tex := _piece_texture(p)
		if tex:
			# Горизонтальное полено — поворачиваем вертикальную текстуру дров на 90°,
			# иначе волокно растянуто поперёк и выглядит неправильно.
			if p.id != "chest" and p.w > p.h:
				_draw_log_horizontal(tex, inner)
			else:
				_grid_ctrl.draw_texture_rect(tex, inner, false)
		else:
			_grid_ctrl.draw_rect(inner, _piece_color(p.id, p.w, p.h))
		if i == _selected:
			_grid_ctrl.draw_rect(inner, C_SELECT)
		_grid_ctrl.draw_rect(inner, C_PIECE_EDGE, false, 1.5)

func _piece_texture(p: Piece) -> Texture2D:
	if p.id == "chest":
		return _tex_chest
	if p.w >= 2 or p.h >= 2:
		return _tex_logs
	return _tex_coal

# Рисует текстуру дров, повёрнутую на 90° (для горизонтального полена).
func _draw_log_horizontal(tex: Texture2D, rect: Rect2) -> void:
	var center := rect.position + rect.size * 0.5
	_grid_ctrl.draw_set_transform(center, PI * 0.5, Vector2.ONE)
	# Локальный прямоугольник с переставленными сторонами: после поворота ляжет в rect.
	var local := Rect2(-rect.size.y * 0.5, -rect.size.x * 0.5, rect.size.y, rect.size.x)
	_grid_ctrl.draw_texture_rect(tex, local, false)
	_grid_ctrl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _piece_color(id: String, w: int, h: int) -> Color:
	if id == "chest":
		return C_CHEST
	if w >= 2 or h >= 2:
		return C_LOG_VERT if h > w else C_LOG_HORIZ
	return C_COAL

# ---- Ввод ----

func _on_grid_input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _is_dragging:
		_update_drag(event.position)

func _start_drag(pos: Vector2) -> void:
	var idx := _find_at_pixel(pos)
	if idx < 0:
		return
	_drag_piece       = idx
	_drag_start_mouse = pos
	_drag_start_col   = _pieces[idx].col
	_drag_start_row   = _pieces[idx].row
	_drag_axis        = ""
	_is_dragging      = true
	_selected         = idx
	_grid_ctrl.queue_redraw()

func _update_drag(pos: Vector2) -> void:
	if _drag_piece < 0:
		return
	var delta := pos - _drag_start_mouse
	if _drag_axis == "" and (absf(delta.x) > 5.0 or absf(delta.y) > 5.0):
		_drag_axis = "h" if absf(delta.x) >= absf(delta.y) else "v"
		_compute_drag_bounds()
	if _drag_axis == "":
		return
	# Зажимаем смещение в пределах свободного хода — фигура не лезет сквозь соседей.
	if _drag_axis == "h":
		_anim_offsets[_drag_piece] = Vector2(clampf(delta.x, _drag_lo, _drag_hi), 0.0)
	else:
		_anim_offsets[_drag_piece] = Vector2(0.0, clampf(delta.y, _drag_lo, _drag_hi))
	_grid_ctrl.queue_redraw()

# Считает диапазон свободного скольжения фигуры по текущей оси (в пикселях от старта).
func _compute_drag_bounds() -> void:
	var p: Piece = _pieces[_drag_piece]
	if _drag_axis == "h":
		var lo := _max_slide_h(_drag_piece, 0)
		var hi := _max_slide_h(_drag_piece, GRID_COLS - p.w)
		_drag_lo = float((lo - _drag_start_col) * CELL_SIZE)
		_drag_hi = float((hi - _drag_start_col) * CELL_SIZE)
	else:
		var lo := _max_slide_v(_drag_piece, 0)
		var hi := _max_slide_v(_drag_piece, GRID_ROWS - p.h)
		_drag_lo = float((lo - _drag_start_row) * CELL_SIZE)
		_drag_hi = float((hi - _drag_start_row) * CELL_SIZE)

func _end_drag(pos: Vector2) -> void:
	if not _is_dragging or _drag_piece < 0:
		_is_dragging = false
		return
	_is_dragging = false
	# Текущее визуальное смещение (откуда пальцем отпустили) — с него и поедет твин.
	var release_off: Vector2 = _anim_offsets.get(_drag_piece, Vector2.ZERO)

	var p: Piece = _pieces[_drag_piece]
	var delta := pos - _drag_start_mouse
	var target_col := _drag_start_col
	var target_row := _drag_start_row

	if _drag_axis == "h":
		var wish := _drag_start_col + int(roundf(delta.x / float(CELL_SIZE)))
		target_col = _max_slide_h(_drag_piece, clampi(wish, 0, GRID_COLS - p.w))
	elif _drag_axis == "v":
		var wish := _drag_start_row + int(roundf(delta.y / float(CELL_SIZE)))
		target_row = _max_slide_v(_drag_piece, clampi(wish, 0, GRID_ROWS - p.h))

	if target_col != _drag_start_col or target_row != _drag_start_row:
		_moves += 1
		if _moves_label:
			_moves_label.text = "Ходы: %d" % _moves
	# Всегда плавно доводим до клетки от места отпускания (даже если ход нулевой) —
	# без скачка обратно в исходную клетку.
	_animate_to(_drag_piece, _drag_start_col, _drag_start_row, target_col, target_row, release_off)

	_drag_piece = -1
	_drag_axis  = ""

# ---- Логика доски ----

func _find_at_pixel(pos: Vector2) -> int:
	return _find_at(int(pos.y / float(CELL_SIZE)), int(pos.x / float(CELL_SIZE)))

func _find_at(row: int, col: int) -> int:
	for i in _pieces.size():
		var p: Piece = _pieces[i]
		if col >= p.col and col < p.col + p.w and row >= p.row and row < p.row + p.h:
			return i
	return -1

func _cell_free(row: int, col: int, skip: int) -> bool:
	if col < 0 or col >= GRID_COLS or row < 0 or row >= GRID_ROWS:
		return false
	for i in _pieces.size():
		if i == skip:
			continue
		var p: Piece = _pieces[i]
		if col >= p.col and col < p.col + p.w and row >= p.row and row < p.row + p.h:
			return false
	return true

func _max_slide_h(idx: int, wish_col: int) -> int:
	var p: Piece = _pieces[idx]
	var dir := signi(wish_col - p.col)
	if dir == 0:
		return p.col
	var cur := p.col
	while cur != wish_col:
		var nxt  := cur + dir
		var edge := nxt + p.w - 1 if dir > 0 else nxt
		var ok   := true
		for dr in p.h:
			if not _cell_free(p.row + dr, edge, idx):
				ok = false; break
		if not ok:
			break
		cur = nxt
	return cur

func _max_slide_v(idx: int, wish_row: int) -> int:
	var p: Piece = _pieces[idx]
	var dir := signi(wish_row - p.row)
	if dir == 0:
		return p.row
	var cur := p.row
	while cur != wish_row:
		var nxt  := cur + dir
		var edge := nxt + p.h - 1 if dir > 0 else nxt
		var ok   := true
		for dc in p.w:
			if not _cell_free(edge, p.col + dc, idx):
				ok = false; break
		if not ok:
			break
		cur = nxt
	return cur

func _check_win() -> void:
	for p: Piece in _pieces:
		if p.id == "chest" and p.col == WIN_COL and p.row == WIN_ROW:
			_trigger_win()
			return

# ---- Анимация ----

func _animate_to(idx: int, from_col: int, from_row: int, to_col: int, to_row: int, release_off: Vector2 = Vector2.ZERO) -> void:
	var p: Piece = _pieces[idx]
	p.col = to_col
	p.row = to_row
	# Старт твина = реальное место отпускания относительно НОВОЙ клетки:
	# (from-to)*CELL приводит базу from к базе to, release_off — «довес» от пальца.
	var start_off := Vector2(
		float((from_col - to_col) * CELL_SIZE),
		float((from_row - to_row) * CELL_SIZE)
	) + release_off
	_anim_offsets[idx] = start_off
	_can_interact = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_anim_offset.bind(idx), start_off, Vector2.ZERO, TWEEN_SECS)
	_tween.tween_callback(func():
		_anim_offsets.erase(idx)
		_can_interact = true
		_check_win()
		_grid_ctrl.queue_redraw()
	)

func _set_anim_offset(v: Vector2, idx: int) -> void:
	_anim_offsets[idx] = v
	_grid_ctrl.queue_redraw()

func _trigger_win() -> void:
	_can_interact = false
	_selected = -1
	var tw := create_tween()
	tw.tween_property(_grid_ctrl, "modulate", Color(1.5, 1.4, 0.8), 0.35)
	tw.tween_property(_grid_ctrl, "modulate", Color(1.0, 1.0, 1.0), 0.45)
	await tw.finished

	await get_tree().create_timer(1.0).timeout
	puzzle_solved.emit(_moves)
	queue_free()  # закрываем пазл — амулет появится снаружи

func _unhandled_input(event: InputEvent) -> void:
	if _can_interact and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# Пример подключения:
# var puzzle := KlotskiPuzzle.new()
# add_child(puzzle)
# puzzle.puzzle_solved.connect(func(moves): ...)
# puzzle.puzzle_closed.connect(func(): player.unfreeze())
# puzzle.open()
