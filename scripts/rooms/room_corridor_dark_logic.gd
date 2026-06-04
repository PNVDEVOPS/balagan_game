extends Node2D

const DARKNESS_SPEED   := 45.0
const SCRIPTED_SPEED   := 95.0   # чуть медленнее ходьбы (100) — убежать можно, стоять нельзя
const DARKNESS_START_R := 1700.0 # старт справа (обычный режим)
const DARKNESS_START_L := -100.0 # старт слева (скриптовый режим, погоня сзади)
const ROOM_WIDTH       := 1600.0
const SHAKE_PROXIMITY  := 380.0
const ZOOM_MAX         := 1.18
const BOOST_REQUIRED   := 3.0
const EDGE_WIDTH       := 450.0
const SCRIPTED_DELAY   := 1.6    # передышка перед стартом погони

# Счётчик посещений dark_c2 — сохраняется между загрузками комнат
static var _dark_c2_visit_count: int = 0

var _darkness:        Polygon2D
var _darkness_edge:   Polygon2D
var _darkness_x:      float
var _dir:             float   = -1.0  # -1 = идёт влево (справа), +1 = идёт вправо (слева)
var _active:          bool    = false
var _defeated:        bool    = false
var _penalty_done:    bool    = false
var _shake_time:      float   = 0.0
var _pulse_time:      float   = 0.0
var _base_zoom:       Vector2 = Vector2(1.0, 1.0)
var _boost_hold_time: float   = 0.0
var _scripted_mode:   bool    = false

func _ready() -> void:
	var is_dark_c2: bool = (GameManager.current_room == "dark_c2")
	_scripted_mode = is_dark_c2 and _dark_c2_visit_count == 0
	if is_dark_c2:
		_dark_c2_visit_count += 1

	if _scripted_mode:
		_dir = 1.0
		_darkness_x = DARKNESS_START_L
	else:
		_dir = -1.0
		_darkness_x = DARKNESS_START_R

	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left  = 0
			cam.limit_right = int(ROOM_WIDTH)
			_base_zoom      = cam.zoom

	_build_darkness()

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	_add_back_zone()
	_setup_intro()

func _setup_intro() -> void:
	await get_tree().create_timer(0.6).timeout
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null

	if _scripted_mode:
		# Фонарик мигает и гаснет — персонаж комментирует в диалоге
		if flashlight and flashlight.has_method("scripted_flicker"):
			flashlight.scripted_flicker(1.0)
		await get_tree().create_timer(0.5).timeout
		DialogueManager.show_text("", "Фонарь… гаснет. Нет, только не сейчас.")
		await DialogueManager.dialogue_finished
		DialogueManager.show_text("Кыдаана", "Ты не уйдёшь от меня.")
		await DialogueManager.dialogue_finished
		if flashlight and flashlight.has_method("scripted_off"):
			flashlight.scripted_off()
		await get_tree().create_timer(SCRIPTED_DELAY).timeout
	else:
		if flashlight and flashlight.has_method("scripted_flicker"):
			flashlight.scripted_flicker(0.8)
		await get_tree().create_timer(0.6).timeout
		DialogueManager.show_text("", "Воздух сгустился. Что-то надвигается.")
		await DialogueManager.dialogue_finished

	_active = true

func _build_darkness() -> void:
	# Мягкий передний край (градиент). Сторона зависит от направления.
	_darkness_edge = Polygon2D.new()
	_darkness_edge.color   = Color(0.0, 0.0, 0.02, 0.22)
	_darkness_edge.z_index = 49
	add_child(_darkness_edge)

	_darkness = Polygon2D.new()
	_darkness.color   = Color(0.0, 0.0, 0.02, 0.97)
	_darkness.z_index = 50
	add_child(_darkness)

	if _dir < 0.0:
		# Идёт влево: тело тянется вправо от позиции, край слева
		_darkness.polygon = PackedVector2Array([
			Vector2(0, -60), Vector2(2400, -60),
			Vector2(2400, 430), Vector2(0, 430),
		])
		_darkness_edge.polygon = PackedVector2Array([
			Vector2(0, -60), Vector2(EDGE_WIDTH, -60),
			Vector2(EDGE_WIDTH, 430), Vector2(0, 430),
		])
	else:
		# Идёт вправо: тело тянется влево от позиции, край справа
		_darkness.polygon = PackedVector2Array([
			Vector2(-2400, -60), Vector2(0, -60),
			Vector2(0, 430), Vector2(-2400, 430),
		])
		_darkness_edge.polygon = PackedVector2Array([
			Vector2(0, -60), Vector2(EDGE_WIDTH, -60),
			Vector2(EDGE_WIDTH, 430), Vector2(0, 430),
		])
	_sync_positions()

func _sync_positions() -> void:
	_darkness.position.x = _darkness_x
	if _dir < 0.0:
		_darkness_edge.position.x = _darkness_x - EDGE_WIDTH
	else:
		_darkness_edge.position.x = _darkness_x

func _process(delta: float) -> void:
	if not _active or _defeated or _penalty_done:
		return

	_pulse_time += delta

	var player := get_node_or_null("Player")
	if not player:
		return

	if _scripted_mode:
		_process_scripted(delta, player)
		return

	# Обычный режим: пульс, буст, зум, шейк
	var pulse: float = 0.5 + 0.5 * absf(sin(_pulse_time * PI * 1.1))

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_boost_hold_time += delta
		_darkness_x -= _dir * 20.0 * delta  # отталкиваем тьму от игрока
		_sync_positions()
		if _boost_hold_time >= BOOST_REQUIRED:
			_dispel_darkness(player)
		return
	else:
		_boost_hold_time = 0.0

	_darkness_x += _dir * DARKNESS_SPEED * delta * pulse
	_sync_positions()

	var alpha_pulse: float = 0.88 + 0.09 * absf(sin(_pulse_time * PI * 1.5))
	_darkness.color      = Color(0.0, 0.0, 0.02, alpha_pulse)
	_darkness_edge.color = Color(0.0, 0.0, 0.02, 0.15 + 0.08 * absf(sin(_pulse_time * PI * 1.5)))

	var dist: float = _dir * (player.global_position.x - _darkness_x)
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

func _process_scripted(delta: float, player: Node) -> void:
	# Погоня сзади (слева направо). Фонарь не работает — надо бежать.
	_darkness_x += _dir * SCRIPTED_SPEED * delta
	_sync_positions()

	# Мягкий ровный шейк (не дёрганый)
	_shake_time += delta * 16.0
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		cam.offset = Vector2(
			sin(_shake_time * 1.3) * 5.0,
			sin(_shake_time * 1.9) * 3.5
		)

	var dist: float = _dir * (player.global_position.x - _darkness_x)
	if dist <= 0.0:
		_trigger_penalty(player)

func _dispel_darkness(player: Node) -> void:
	_defeated = true
	_active   = false
	_reset_camera(player)
	var back_x: float = DARKNESS_START_R if _dir < 0.0 else DARKNESS_START_L
	var edge_back: float = back_x - EDGE_WIDTH if _dir < 0.0 else back_x
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_darkness,      "position:x", back_x,    1.2)
	tween.tween_property(_darkness_edge, "position:x", edge_back, 1.0)
	tween.tween_property(_darkness_edge, "modulate:a", 0.0,       0.8)

func _trigger_penalty(player: Node) -> void:
	_penalty_done = true
	_active       = false
	_reset_camera(player)
	_restore_flashlight(player)
	var two_back := _room_two_back()
	if two_back.is_empty():
		GameManager.change_room("door_back")
	else:
		GameManager.change_room_direct(two_back, "door_back")

func _restore_flashlight(player_body: Node) -> void:
	if not _scripted_mode:
		return
	var fl = player_body.get_node_or_null("Flashlight") if player_body else null
	if fl and fl.has_method("scripted_on"):
		fl.scripted_on()

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
	var area  := Area2D.new()
	area.name  = "BackZone"
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size          = Vector2(40, 400)
	shape.position     = Vector2(0, 180)
	shape.shape        = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			GameManager.change_room("door_back")
	)

func _on_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_restore_flashlight(body)
	GameManager.change_room("door_forward")
