extends CharacterBody2D

const PATROL_SPEED := 30.0
const CHASE_SPEED := 60.0
const DETECTION_RANGE := 80.0
const DETECTION_ANGLE := 60.0
const ALERT_TIME := 2.0
const GRAVITY := 600.0

enum State { PATROL, ALERT, CHASE, BANISHED }

@export var patrol_points: Array[Vector2] = []
@export var facing_right: bool = true

var state: State = State.PATROL
var current_patrol_index: int = 0
var alert_timer: float = 0.0
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var glow: PointLight2D = $Glow

func _ready() -> void:
	modulate = Color(0.2, 0.1, 0.3, 0.7)
	detection_area.body_entered.connect(_on_body_entered_detection)
	detection_area.body_exited.connect(_on_body_exited_detection)
	if patrol_points.is_empty():
		patrol_points = [global_position + Vector2(-60, 0), global_position + Vector2(60, 0)]

func _physics_process(delta: float) -> void:
	if state == State.BANISHED:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.PATROL:
			_patrol(delta)
		State.ALERT:
			_alert(delta)
		State.CHASE:
			_chase(delta)

	move_and_slide()

func _patrol(_delta: float) -> void:
	var target: Vector2 = patrol_points[current_patrol_index]
	var direction: float = sign(target.x - global_position.x)
	velocity.x = direction * PATROL_SPEED
	facing_right = direction > 0
	sprite.flip_h = not facing_right

	if abs(global_position.x - target.x) < 5.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _alert(delta: float) -> void:
	velocity.x = 0
	alert_timer -= delta
	if alert_timer <= 0:
		if player_ref and _can_see_player():
			state = State.CHASE
		else:
			state = State.PATROL

func _chase(_delta: float) -> void:
	if not player_ref:
		state = State.PATROL
		return
	if player_ref.is_hiding:
		state = State.PATROL
		player_ref = null
		return
	var direction: float = sign(player_ref.global_position.x - global_position.x)
	velocity.x = direction * CHASE_SPEED
	facing_right = direction > 0
	sprite.flip_h = not facing_right

	var distance := global_position.distance_to(player_ref.global_position)
	if distance < 25.0:
		_initiate_qte()

func _on_body_entered_detection(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("_start_crank"):
		if body.is_hiding:
			return
		player_ref = body
		state = State.ALERT
		alert_timer = ALERT_TIME

func _on_body_exited_detection(body: Node2D) -> void:
	if body == player_ref and state == State.ALERT:
		state = State.PATROL

func _can_see_player() -> bool:
	if not player_ref:
		return false
	return not player_ref.is_hiding

func _initiate_qte() -> void:
	state = State.BANISHED
	velocity.x = 0
	if player_ref and player_ref.has_node("Flashlight"):
		var fl = player_ref.get_node("Flashlight")
		fl.start_qte()
		var qte_overlay = get_tree().get_first_node_in_group("qte_overlay")
		if qte_overlay:
			qte_overlay.start_qte(fl)
		fl.qte_success.connect(func(): banish(), CONNECT_ONE_SHOT)
		fl.qte_failure.connect(func(): GameManager.teleport_to_random_room(), CONNECT_ONE_SHOT)

func banish() -> void:
	state = State.BANISHED
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()
