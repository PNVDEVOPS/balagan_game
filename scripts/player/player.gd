extends CharacterBody2D

const WALK_SPEED := 80.0
const RUN_SPEED := 140.0
const GRAVITY := 600.0

var facing_right := true
var is_interacting := false
var is_hiding := false
var is_frozen := false
var nearest_interactable: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray: RayCast2D = $InteractionRay
@onready var flashlight_ctrl = $Flashlight
@onready var camera: Camera2D = $Camera2D
@onready var prompt: Sprite2D = $InteractionPrompt
@onready var interaction_ring: Node2D = $InteractionRing
@onready var interaction_label: Label = $InteractionLabel

func _ready() -> void:
	ray.collide_with_areas = true
	prompt.visible = false
	flashlight_ctrl.set_facing(true)
	if interaction_ring:
		interaction_ring.modulate.a = 0.0
	if interaction_label:
		interaction_label.modulate.a = 0.0

func _physics_process(delta: float) -> void:
	var blocked := is_hiding or is_interacting or is_frozen or DialogueManager.is_active
	if blocked:
		velocity.x = 0
	else:
		_handle_movement()

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()
	_update_animation()
	_check_interaction()

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var is_running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if is_running else WALK_SPEED

	velocity.x = direction * speed

	if direction > 0:
		facing_right = true
		sprite.flip_h = false
		ray.target_position = Vector2(30, 0)
		flashlight_ctrl.set_facing(true)
	elif direction < 0:
		facing_right = false
		sprite.flip_h = true
		ray.target_position = Vector2(-30, 0)
		flashlight_ctrl.set_facing(false)

func _update_animation() -> void:
	if is_hiding:
		return
	if is_frozen or DialogueManager.is_active:
		sprite.play("idle")
		return
	if is_interacting:
		sprite.play("crank")
		return
	if abs(velocity.x) < 1.0:
		sprite.play("idle")
	elif Input.is_action_pressed("run"):
		sprite.play("run")
	else:
		sprite.play("walk")

func _check_interaction() -> void:
	if ray.is_colliding():
		var collider := ray.get_collider()
		if collider and collider.has_method("get_interaction_type"):
			nearest_interactable = collider
			prompt.visible = false
			if interaction_ring:
				interaction_ring.global_position = collider.global_position
				interaction_ring.modulate.a = 0.85
			if interaction_label:
				interaction_label.global_position = collider.global_position + Vector2(0.0, -40.0)
				interaction_label.modulate.a = 0.85
			return
	nearest_interactable = null
	prompt.visible = false
	if interaction_ring:
		interaction_ring.modulate.a = 0.0
	if interaction_label:
		interaction_label.modulate.a = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Dialogue advancement always works, even while frozen
	if DialogueManager.is_active:
		if event.is_action_pressed("advance_dialogue"):
			DialogueManager.advance()
		return

	if is_frozen:
		return

	if flashlight_ctrl.is_qte_active:
		if event.is_action_pressed("interact"):
			flashlight_ctrl.qte_press()
		return

	if event.is_action_pressed("interact"):
		if nearest_interactable:
			nearest_interactable.interact(self)
	elif event.is_action_pressed("crank"):
		_start_crank()
	elif event.is_action_released("crank"):
		_stop_crank()
	elif event.is_action_pressed("hide") and nearest_interactable:
		if nearest_interactable.has_method("hide_player"):
			nearest_interactable.hide_player(self)

func _start_crank() -> void:
	if flashlight_ctrl.is_scripted_off or flashlight_ctrl.is_qte_active:
		return
	is_interacting = true
	flashlight_ctrl.crank()

func _stop_crank() -> void:
	is_interacting = false
	flashlight_ctrl.stop_crank()

func freeze() -> void:
	is_frozen = true
	velocity = Vector2.ZERO

func unfreeze() -> void:
	is_frozen = false
