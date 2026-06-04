extends Node2D

const DARKNESS_SPEED   := 28.0
const DARKNESS_START_X := 1700.0
const START_DELAY      := 2.5
const ROOM_WIDTH       := 1600.0
const SHAKE_PROXIMITY  := 250.0

var _darkness: Polygon2D
var _darkness_x: float = DARKNESS_START_X
var _active: bool = false
var _defeated: bool = false
var _penalty_done: bool = false
var _shake_time: float = 0.0

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left  = 0
			cam.limit_right = int(ROOM_WIDTH)

	_build_darkness()

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	_add_back_zone()

	get_tree().create_timer(START_DELAY).timeout.connect(func(): _active = true)

func _build_darkness() -> void:
	_darkness = Polygon2D.new()
	_darkness.polygon = PackedVector2Array([
		Vector2(0,    -60),
		Vector2(2000, -60),
		Vector2(2000,  420),
		Vector2(0,     420),
	])
	_darkness.color   = Color(0.0, 0.0, 0.02, 0.97)
	_darkness.z_index = 50
	_darkness.position.x = _darkness_x
	add_child(_darkness)

func _process(delta: float) -> void:
	if not _active or _defeated or _penalty_done:
		return

	_darkness_x         -= DARKNESS_SPEED * delta
	_darkness.position.x = _darkness_x

	var player := get_node_or_null("Player")
	if not player:
		return

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_dispel_darkness(player)
		return

	var dist: float = _darkness_x - player.global_position.x
	if dist < SHAKE_PROXIMITY:
		_shake_time += delta * 18.0
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.offset = Vector2(
				sin(_shake_time)        * lerp(0.0, 4.0, 1.0 - dist / SHAKE_PROXIMITY),
				sin(_shake_time * 0.7)  * lerp(0.0, 3.0, 1.0 - dist / SHAKE_PROXIMITY)
			)

	if dist <= 0.0:
		_trigger_penalty(player)

func _dispel_darkness(player: Node) -> void:
	_defeated = true
	_active   = false
	_reset_camera(player)
	var tween := create_tween()
	tween.tween_property(_darkness, "position:x", DARKNESS_START_X, 1.2)

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
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.3)

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
