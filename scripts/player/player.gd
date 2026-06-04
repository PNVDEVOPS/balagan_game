extends CharacterBody2D

const WALK_SPEED := 100.0
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
@onready var prompt: Node2D = $InteractionPrompt

func _ready() -> void:
	ray.collide_with_areas = true
	prompt.visible = false
	flashlight_ctrl.set_facing(true)

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
	position = position.round()
	_update_animation()
	_check_interaction()

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * WALK_SPEED

	if direction > 0:
		facing_right = true
		sprite.flip_h = false
		ray.target_position = Vector2(50, 0)
		flashlight_ctrl.set_facing(true)
	elif direction < 0:
		facing_right = false
		sprite.flip_h = true
		ray.target_position = Vector2(-50, 0)
		flashlight_ctrl.set_facing(false)

func _update_animation() -> void:
	if is_hiding:
		return
	if is_frozen or DialogueManager.is_active:
		sprite.play("idle")
		return
	if is_interacting:
		sprite.play("idle")
		return
	if abs(velocity.x) < 1.0:
		sprite.play("idle")
	else:
		sprite.play("walk")

func _check_interaction() -> void:
	if ray.is_colliding():
		var collider := ray.get_collider()
		if collider and collider.has_method("get_interaction_type"):
			nearest_interactable = collider
			# Иконка-глаз с [E] над головой — появляется при приближении
			prompt.visible = true
			return
	nearest_interactable = null
	prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	# Dialogue advancement always works, even while frozen
	if DialogueManager.is_active:
		if event.is_action_pressed("advance_dialogue") and not NotePopup.is_open:
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
	elif event.is_action_pressed("crank") and not event.is_echo():
		# Спам F накачивает фонарь. Echo (зажатие) игнорируем — нужны реальные нажатия.
		# Не блокирует ходьбу — можно качать на бегу.
		flashlight_ctrl.pump()
	elif event.is_action_pressed("hide") and nearest_interactable:
		if nearest_interactable.has_method("hide_player"):
			nearest_interactable.hide_player(self)

func freeze() -> void:
	is_frozen = true
	velocity = Vector2.ZERO

func unfreeze() -> void:
	is_frozen = false
