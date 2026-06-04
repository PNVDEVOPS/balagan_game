extends Node2D

# Две тёмные комнаты — две механики:
#   dark_c1 — тьма наползает спереди, рассеивается накачкой фонаря (спам F).
#   dark_c2 — гейт масляной лампы:
#       без лампы → Кыдаана гонит назад, фонарь гаснет («нужен свет»);
#       с лампой  → тьма расступается, проход свободен вперёд.

const DARKNESS_SPEED  := 45.0
const START_X_RIGHT   := 1700.0
const ROOM_WIDTH      := 1600.0
const SHAKE_PROXIMITY  := 380.0
const ZOOM_MAX        := 1.18
const BOOST_REQUIRED  := 3.0
const EDGE_WIDTH      := 450.0
const RETREAT_SPEED   := 60.0    # тьма гонит игрока назад (dark_c2 без лампы)

var _mode: String = "dispel"     # "dispel" | "lamp_pass" | "lamp_retreat"

var _darkness:        Polygon2D
var _darkness_edge:   Polygon2D
var _darkness_x:      float   = START_X_RIGHT
var _active:          bool    = false
var _defeated:        bool    = false
var _penalty_done:    bool    = false
var _shake_time:      float   = 0.0
var _pulse_time:      float   = 0.0
var _base_zoom:       Vector2 = Vector2.ONE
var _boost_hold_time: float   = 0.0

func _ready() -> void:
	var is_c2 := GameManager.current_room == "dark_c2"
	if Inventory.has_item("oil_lamp"):
		_mode = "lamp_pass"                          # лампа держит тьму
	elif GameManager.spawn_door_id == "door_back":
		_mode = "free_pass"                          # идём назад — тьма не мешает
	elif is_c2:
		_mode = "lamp_retreat"                       # Кыдаана гонит назад
	else:
		_mode = "dispel"                             # dark_c1: рассеять накачкой

	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left  = 0
			cam.limit_right = int(ROOM_WIDTH)
			_base_zoom      = cam.zoom

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)
	_add_back_zone()

	# dark_c2 при входе вперёд начинается с середины помещения
	if is_c2 and GameManager.spawn_door_id != "door_back":
		_center_player_deferred()

	match _mode:
		"lamp_pass":
			_setup_lamp_pass()
		"free_pass":
			pass                                     # просто проходим
		"lamp_retreat":
			_build_darkness()
			_setup_retreat_intro()
		_:
			_build_darkness()
			_setup_dispel_intro()

func _center_player_deferred() -> void:
	await get_tree().create_timer(0.15).timeout
	var p := get_node_or_null("Player")
	if p:
		p.global_position.x = ROOM_WIDTH * 0.5

# ── общая тьма: тело тянется вправо, мягкий край слева ──────────────────
func _build_darkness() -> void:
	_darkness_edge = Polygon2D.new()
	_darkness_edge.polygon = PackedVector2Array([
		Vector2(0, -60), Vector2(EDGE_WIDTH, -60),
		Vector2(EDGE_WIDTH, 430), Vector2(0, 430),
	])
	_darkness_edge.color   = Color(0.0, 0.0, 0.02, 0.22)
	_darkness_edge.z_index = 49
	add_child(_darkness_edge)

	_darkness = Polygon2D.new()
	_darkness.polygon = PackedVector2Array([
		Vector2(0, -60), Vector2(2400, -60),
		Vector2(2400, 430), Vector2(0, 430),
	])
	_darkness.color   = Color(0.0, 0.0, 0.02, 0.97)
	_darkness.z_index = 50
	add_child(_darkness)
	_sync_positions()

func _sync_positions() -> void:
	_darkness.position.x      = _darkness_x
	_darkness_edge.position.x = _darkness_x - EDGE_WIDTH

# ── dark_c1: рассеять накачкой фонаря ──────────────────────────────────
func _setup_dispel_intro() -> void:
	await get_tree().create_timer(0.6).timeout
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	if flashlight and flashlight.has_method("scripted_flicker"):
		flashlight.scripted_flicker(0.8)
	await get_tree().create_timer(0.6).timeout
	DialogueManager.show_text("", "Воздух сгустился. Что-то надвигается.")
	await DialogueManager.dialogue_finished
	_active = true

# ── dark_c2 без лампы: Кыдаана гонит назад, фонарь гаснет ───────────────
func _setup_retreat_intro() -> void:
	await get_tree().create_timer(0.5).timeout
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	# Дожидаемся мигания (оно само включает фонарь в конце), потом гасим насовсем
	if flashlight and flashlight.has_method("scripted_flicker"):
		await flashlight.scripted_flicker(0.7)
	if flashlight and flashlight.has_method("scripted_off"):
		flashlight.scripted_off()

	if not GameManager.lamp_needed:
		DialogueManager.show_text("Кыдаана", "Уходи.")
		await DialogueManager.dialogue_finished
		GameManager.lamp_needed = true
	else:
		DialogueManager.show_text("", "Фонарик не работает. Дальше не пройти — мне нужен свет.")
		await DialogueManager.dialogue_finished
	_active = true

# ── dark_c2 с лампой: тьма расступается, иди вперёд ─────────────────────
func _setup_lamp_pass() -> void:
	await get_tree().create_timer(0.4).timeout
	SubtitleManager.show_subtitle("Лампа держит тьму на расстоянии.", SubtitleManager.Pos.BOTTOM_CENTER)

func _process(delta: float) -> void:
	if not _active or _defeated or _penalty_done:
		return
	var player := get_node_or_null("Player")
	if not player:
		return
	if _mode == "lamp_retreat":
		_process_retreat(delta, player)
	else:
		_process_dispel(delta, player)

func _process_retreat(delta: float, player: Node) -> void:
	_darkness_x -= RETREAT_SPEED * delta
	_sync_positions()
	_shake_time += delta * 16.0
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.offset = Vector2(sin(_shake_time * 1.3) * 5.0, sin(_shake_time * 1.9) * 3.5)
	var dist: float = _darkness_x - player.global_position.x
	if dist <= 0.0:
		_penalty_done = true
		_active = false
		# Тьма отбрасывает в комнату, откуда пришёл
		GameManager.change_room("door_back")

func _process_dispel(delta: float, player: Node) -> void:
	_pulse_time += delta
	var pulse: float = 0.5 + 0.5 * absf(sin(_pulse_time * PI * 1.1))

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_boost_hold_time += delta
		_darkness_x += 20.0 * delta
		_sync_positions()
		if _boost_hold_time >= BOOST_REQUIRED:
			_dispel_darkness(player)
		return
	else:
		_boost_hold_time = 0.0

	_darkness_x -= DARKNESS_SPEED * delta * pulse
	_sync_positions()

	var alpha_pulse: float = 0.88 + 0.09 * absf(sin(_pulse_time * PI * 1.5))
	_darkness.color      = Color(0.0, 0.0, 0.02, alpha_pulse)
	_darkness_edge.color = Color(0.0, 0.0, 0.02, 0.15 + 0.08 * absf(sin(_pulse_time * PI * 1.5)))

	var dist: float = _darkness_x - player.global_position.x
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		var t := clampf(1.0 - dist / ROOM_WIDTH, 0.0, 1.0)
		var target_zoom: float = lerpf(1.0, ZOOM_MAX, t)
		cam.zoom = cam.zoom.lerp(Vector2(target_zoom, target_zoom), delta * 2.5)

	if dist < SHAKE_PROXIMITY:
		_shake_time += delta * 22.0
		var intensity: float = 1.0 - dist / SHAKE_PROXIMITY
		if cam:
			cam.offset = Vector2(
				sin(_shake_time)       * lerpf(0.0, 11.0, intensity),
				sin(_shake_time * 0.7) * lerpf(0.0,  8.0, intensity)
			)

	if dist <= 0.0:
		_trigger_penalty(player)

func _dispel_darkness(player: Node) -> void:
	_defeated = true
	_active   = false
	_reset_camera(player)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_darkness,      "position:x", START_X_RIGHT,             1.2)
	tween.tween_property(_darkness_edge, "position:x", START_X_RIGHT - EDGE_WIDTH, 1.0)
	tween.tween_property(_darkness_edge, "modulate:a", 0.0,                        0.8)

func _trigger_penalty(player: Node) -> void:
	_penalty_done = true
	_active       = false
	_reset_camera(player)
	var two_back := _room_two_back()
	if two_back.is_empty():
		GameManager.change_room("door_back")
	else:
		GameManager.change_room_direct(two_back, "door_back")

func _room_two_back() -> String:
	var r1 := GameManager.get_door_target(GameManager.current_room, "door_back")
	if r1.is_empty():
		return ""
	return GameManager.get_door_target(r1, "door_back")

func _reset_camera(player: Node) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.5)
		tween.tween_property(cam, "zoom",   _base_zoom,   0.5)

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size      = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape    = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			GameManager.change_room("door_back")
	)

func _on_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _mode == "lamp_retreat":
		return  # вперёд хода нет без света
	GameManager.change_room("door_forward")
