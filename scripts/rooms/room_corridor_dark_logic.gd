extends Node2D

const DARKNESS_SPEED   := 45.0
const DARKNESS_START_X := 1700.0
const ROOM_WIDTH       := 1600.0
const SHAKE_PROXIMITY  := 380.0
const ZOOM_MAX         := 1.18

var _darkness:      Polygon2D
var _darkness_edge: Polygon2D
var _darkness_x:    float = DARKNESS_START_X
var _active:        bool  = false
var _defeated:      bool  = false
var _penalty_done:  bool  = false
var _shake_time:    float = 0.0
var _pulse_time:    float = 0.0
var _base_zoom:     Vector2 = Vector2(1.0, 1.0)

func _ready() -> void:
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
	await get_tree().create_timer(0.4).timeout
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	if flashlight and flashlight.has_method("scripted_flicker"):
		flashlight.scripted_flicker(0.8)
	await get_tree().create_timer(0.6).timeout
	SubtitleManager.show_subtitle("Воздух сгустился. Что-то надвигается...", SubtitleManager.Pos.MID_LEFT)
	await get_tree().create_timer(2.0).timeout
	_active = true

func _build_darkness() -> void:
	# Мягкий передний край (градиент)
	_darkness_edge = Polygon2D.new()
	_darkness_edge.polygon = PackedVector2Array([
		Vector2(0,   -60),
		Vector2(220, -60),
		Vector2(220,  430),
		Vector2(0,    430),
	])
	_darkness_edge.color   = Color(0.0, 0.0, 0.02, 0.38)
	_darkness_edge.z_index = 49
	_darkness_edge.position.x = _darkness_x - 220.0
	add_child(_darkness_edge)

	# Основное тело тьмы
	_darkness = Polygon2D.new()
	_darkness.polygon = PackedVector2Array([
		Vector2(0,    -60),
		Vector2(2000, -60),
		Vector2(2000,  430),
		Vector2(0,     430),
	])
	_darkness.color   = Color(0.0, 0.0, 0.02, 0.97)
	_darkness.z_index = 50
	_darkness.position.x = _darkness_x
	add_child(_darkness)

func _process(delta: float) -> void:
	if not _active or _defeated or _penalty_done:
		return

	_pulse_time += delta

	# Пульсирующая скорость (биение сердца ~1.1 Гц)
	var pulse: float = 0.5 + 0.5 * absf(sin(_pulse_time * PI * 1.1))
	_darkness_x              -= DARKNESS_SPEED * delta * pulse
	_darkness.position.x      = _darkness_x
	_darkness_edge.position.x = _darkness_x - 220.0

	# Пульсация непрозрачности
	var alpha_pulse: float = 0.88 + 0.09 * absf(sin(_pulse_time * PI * 1.5))
	_darkness.color      = Color(0.0, 0.0, 0.02, alpha_pulse)
	_darkness_edge.color = Color(0.0, 0.0, 0.02, 0.28 + 0.18 * abs(sin(_pulse_time * PI * 1.5)))

	var player := get_node_or_null("Player")
	if not player:
		return

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_dispel_darkness(player)
		return

	var dist: float = _darkness_x - player.global_position.x
	var cam: Camera2D = player.get_node_or_null("Camera2D")

	# Зум нагнетания
	if cam:
		var t := clampf(1.0 - dist / ROOM_WIDTH, 0.0, 1.0)
		var target_zoom: float = lerpf(1.0, ZOOM_MAX, t)
		cam.zoom = cam.zoom.lerp(Vector2(target_zoom, target_zoom), delta * 2.5)

	# Шейк камеры (нарастает по мере приближения)
	if dist < SHAKE_PROXIMITY:
		_shake_time += delta * 22.0
		var intensity := 1.0 - dist / SHAKE_PROXIMITY
		if cam:
			cam.offset = Vector2(
				sin(_shake_time)        * lerp(0.0, 11.0, intensity),
				sin(_shake_time * 0.7)  * lerp(0.0,  8.0, intensity)
			)

	if dist <= 0.0:
		_trigger_penalty(player)

func _dispel_darkness(player: Node) -> void:
	_defeated = true
	_active   = false
	_reset_camera(player)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_darkness,      "position:x", DARKNESS_START_X,        1.2)
	tween.tween_property(_darkness_edge, "position:x", DARKNESS_START_X - 220.0, 1.2)

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
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
