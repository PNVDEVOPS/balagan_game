class_name SpiritGuardian
extends CharacterBody2D

signal banished()

const PATROL_SPEED := 25.0
const CHASE_SPEED := 45.0
const FLEE_SPEED := 80.0
const MIN_DISTANCE := 150.0       # never closer than this (pixels ≈ 3m)
const BANISH_RANGE_MAX := 400.0   # bright light only banishes within this range
const HOLD_TIME_TO_BANISH := 1.5  # seconds of sustained bright light to banish
const ALERT_TIME := 2.0
const GRAVITY := 600.0

enum State { PATROL, ALERT, CHASE, RETREATING, BANISHED }

@export var patrol_points: Array[Vector2] = []

var state: State = State.PATROL
var current_patrol_index: int = 0
var alert_timer: float = 0.0
var bright_light_timer: float = 0.0
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
	modulate = Color(0.15, 0.08, 0.25, 0.65)
	add_to_group("spirit")
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	if patrol_points.is_empty():
		patrol_points = [global_position + Vector2(-80.0, 0.0), global_position + Vector2(80.0, 0.0)]

func _physics_process(delta: float) -> void:
	if state == State.BANISHED:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.PATROL:     _patrol(delta)
		State.ALERT:      _alert(delta)
		State.CHASE:      _chase(delta)
		State.RETREATING: _retreat(delta)

	_check_bright_light(delta)
	move_and_slide()

func _patrol(_delta: float) -> void:
	var target: Vector2 = patrol_points[current_patrol_index]
	var dir: float = sign(target.x - global_position.x)
	velocity.x = dir * PATROL_SPEED
	sprite.flip_h = dir < 0.0
	if abs(global_position.x - target.x) < 5.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _alert(delta: float) -> void:
	velocity.x = 0.0
	alert_timer -= delta
	if alert_timer <= 0.0:
		state = State.CHASE if (player_ref and _player_visible()) else State.PATROL

func _chase(_delta: float) -> void:
	if not player_ref:
		state = State.PATROL
		return
	if player_ref.is_hiding:
		state = State.PATROL
		player_ref = null
		return

	var dist := global_position.distance_to(player_ref.global_position)
	if dist < MIN_DISTANCE:
		state = State.RETREATING
		return

	var dir: float = sign(player_ref.global_position.x - global_position.x)
	velocity.x = dir * CHASE_SPEED
	sprite.flip_h = dir < 0.0

func _retreat(_delta: float) -> void:
	if not player_ref:
		state = State.PATROL
		return
	var dist := global_position.distance_to(player_ref.global_position)
	if dist >= MIN_DISTANCE + 20.0:
		state = State.CHASE
		return
	var dir: float = -sign(player_ref.global_position.x - global_position.x)
	velocity.x = dir * FLEE_SPEED
	sprite.flip_h = dir < 0.0

func _check_bright_light(delta: float) -> void:
	if state == State.BANISHED or not player_ref:
		bright_light_timer = 0.0
		return

	var fl := _get_player_flashlight()
	if not fl:
		bright_light_timer = 0.0
		return

	var dist := global_position.distance_to(player_ref.global_position)
	var in_banish_range: bool = dist >= MIN_DISTANCE and dist <= BANISH_RANGE_MAX
	var boost_on: bool = fl.is_boost_active and fl.charge > 0.0
	var in_cone: bool = _is_in_flashlight_cone(fl)

	if boost_on and in_banish_range and in_cone:
		bright_light_timer += delta
		velocity.x *= 0.3  # slow down while illuminated
		if bright_light_timer >= HOLD_TIME_TO_BANISH:
			_initiate_banish()
	else:
		bright_light_timer = maxf(bright_light_timer - delta * 0.5, 0.0)

func _is_in_flashlight_cone(fl: Node) -> bool:
	if not player_ref:
		return false
	var facing_right: bool = fl.scale.x > 0.0
	var spirit_is_right: bool = global_position.x > player_ref.global_position.x
	return facing_right == spirit_is_right

func _get_player_flashlight() -> Node:
	if not player_ref:
		return null
	return player_ref.get_node_or_null("Flashlight")

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("freeze") and not body.is_in_group("spirit"):
		if body.is_hiding:
			return
		player_ref = body as CharacterBody2D
		if state == State.PATROL:
			state = State.ALERT
			alert_timer = ALERT_TIME

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref and state == State.ALERT:
		state = State.PATROL
		player_ref = null

func _player_visible() -> bool:
	return player_ref != null and not player_ref.is_hiding

func _initiate_banish() -> void:
	state = State.BANISHED
	velocity = Vector2.ZERO
	bright_light_timer = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	await tween.finished
	banished.emit()
	queue_free()
