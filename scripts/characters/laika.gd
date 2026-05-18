extends CharacterBody2D

const MOVE_SPEED := 70.0
const FOLLOW_DISTANCE := 60.0
const HINT_DISTANCE := 20.0
const IDLE_HINT_TIMEOUT := 60.0
const GRAVITY := 600.0

enum State { IDLE, FOLLOW_PLAYER, LEAD_TO, SIT_AT, DISAPPEAR }
enum Hint { NONE, SIT_AT_DOOR, GROWL, SCRATCH, HAPPY }

@export var hint_target: Node2D = null
@export var auto_appear: bool = true

var state: State = State.IDLE
var current_hint: Hint = Hint.NONE
var player_ref: CharacterBody2D = null
var lead_target: Vector2 = Vector2.ZERO
var idle_timer: float = 0.0
var is_visible_spirit: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow: PointLight2D = $Glow

func _ready() -> void:
	modulate = Color(1, 1, 1, 0.7)
	add_to_group("laika")
	_find_player()
	if not auto_appear:
		disappear()

func _find_player() -> void:
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_visible_spirit:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.FOLLOW_PLAYER:
			_follow_player(delta)
		State.LEAD_TO:
			_lead_to_target(delta)
		State.SIT_AT:
			velocity.x = 0
		State.IDLE:
			velocity.x = 0
			_check_idle_hint(delta)

	move_and_slide()
	_update_animation()
	_bob_glow(delta)

func _follow_player(_delta: float) -> void:
	if not player_ref:
		return
	var dist := global_position.x - player_ref.global_position.x
	if abs(dist) > FOLLOW_DISTANCE:
		var dir := -sign(dist)
		velocity.x = dir * MOVE_SPEED
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0

func _lead_to_target(_delta: float) -> void:
	var dist := lead_target.x - global_position.x
	if abs(dist) > HINT_DISTANCE:
		var dir := sign(dist)
		velocity.x = dir * MOVE_SPEED
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0
		state = State.SIT_AT
		current_hint = Hint.SIT_AT_DOOR

func _check_idle_hint(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= IDLE_HINT_TIMEOUT and hint_target:
		lead_to(hint_target.global_position)
		idle_timer = 0.0

func _update_animation() -> void:
	if abs(velocity.x) > 1.0:
		sprite.play("walk")
	else:
		match current_hint:
			Hint.GROWL:
				sprite.play("growl")
			Hint.SIT_AT_DOOR:
				sprite.play("sit")
			_:
				sprite.play("idle")

func _bob_glow(_delta: float) -> void:
	glow.energy = 0.4 + sin(Time.get_ticks_msec() * 0.003) * 0.1

func appear() -> void:
	is_visible_spirit = true
	visible = true
	var tween := create_tween()
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 0.7, 0.8)

func disappear() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	is_visible_spirit = false
	visible = false

func lead_to(target_pos: Vector2) -> void:
	state = State.LEAD_TO
	lead_target = target_pos

func follow_player() -> void:
	state = State.FOLLOW_PLAYER
	current_hint = Hint.NONE

func sit_at(pos: Vector2) -> void:
	global_position = pos
	state = State.SIT_AT
	current_hint = Hint.SIT_AT_DOOR

func growl() -> void:
	current_hint = Hint.GROWL

func happy() -> void:
	current_hint = Hint.HAPPY

func reset_hint() -> void:
	current_hint = Hint.NONE
	idle_timer = 0.0
