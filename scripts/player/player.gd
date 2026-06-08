extends CharacterBody2D

const WALK_SPEED := 100.0
const RUN_SPEED := 185.0      # ускорение шага на Shift
const GRAVITY := 600.0

# Кадры «с лампой» — отдельный набор спрайтов тела, когда герой несёт лампу.
# Арт нарисован смотрящим ВЛЕВО, поэтому при сборке кадры зеркалим (как и база — вправо).
const LAMP_IDLE_DIR := "res://assets/sprites/player_lamp/idle/"
const LAMP_WALK_DIR := "res://assets/sprites/player_lamp/walk/"

# Шаги по снегу — звучат только в уличных комнатах (Forest/Highway).
const SNOW_ROOMS := ["forest", "highway"]
const SNOW_STEPS := ["res://assets/audio/SnowStepone.mp3", "res://assets/audio/SnowStepTwo.mp3"]
const STEP_DISTANCE := 46.0     # пройденный путь между шагами (меньше = чаще)
const STEP_VOLUME_DB := -3.0    # ← ГРОМКОСТЬ шагов

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

var _base_frames: SpriteFrames = null            # обычные кадры (без предмета)
static var _lamp_frames: SpriteFrames = null     # кадры с лампой (строятся 1 раз за сессию)

var _snow_streams: Array = []                    # звуки шагов по снегу
var _step_accum: float = 0.0                     # накопленный путь до следующего шага
var _step_idx: int = 0                           # чередование SnowStepOne/Two

func _ready() -> void:
	ray.collide_with_areas = true
	prompt.visible = false
	flashlight_ctrl.set_facing(true)
	_base_frames = sprite.sprite_frames
	refresh_appearance()
	for path in SNOW_STEPS:
		if ResourceLoader.exists(path):
			_snow_streams.append(load(path))

# Подбирает набор кадров тела под инвентарь: с лампой — кадры «с лампой», иначе база.
# Никаких предметов в руке отдельным спрайтом больше нет.
func refresh_appearance() -> void:
	if not sprite:
		return
	if Inventory.has_item("oil_lamp"):
		if _lamp_frames == null:
			_lamp_frames = _build_lamp_frames()
		if sprite.sprite_frames != _lamp_frames:
			var anim := sprite.animation
			sprite.sprite_frames = _lamp_frames
			sprite.play(anim if _lamp_frames.has_animation(anim) else "idle")
	elif _base_frames and sprite.sprite_frames != _base_frames:
		var anim := sprite.animation
		sprite.sprite_frames = _base_frames
		sprite.play(anim if _base_frames.has_animation(anim) else "idle")

# Строит SpriteFrames «с лампой»: idle (1 поза) + walk (14 кадров), все отзеркалены.
func _build_lamp_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 4.0)
	var idle_tex := _load_flipped(LAMP_IDLE_DIR + "1.png")
	if idle_tex:
		sf.add_frame("idle", idle_tex)
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", 14.0)
	for i in range(1, 15):
		var t := _load_flipped(LAMP_WALK_DIR + "%d.png" % i)
		if t:
			sf.add_frame("walk", t)
	return sf

# Грузит текстуру и зеркалит её по X (арт смотрит влево → делаем вправо, как база).
func _load_flipped(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var src := load(path) as Texture2D
	if not src:
		return null
	var img := src.get_image()
	img.flip_x()
	return ImageTexture.create_from_image(img)

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
	_handle_footsteps(delta)

# Шаги по снегу: по мере пройденного пути в уличных комнатах чередуем два звука.
func _handle_footsteps(delta: float) -> void:
	if _snow_streams.is_empty() or not SNOW_ROOMS.has(GameManager.current_room):
		return
	if is_frozen or is_hiding or DialogueManager.is_active or not is_on_floor():
		return
	if absf(velocity.x) < 1.0:
		return
	_step_accum += absf(velocity.x) * delta
	if _step_accum >= STEP_DISTANCE:
		_step_accum = 0.0
		AudioManager.play_sfx(_snow_streams[_step_idx], STEP_VOLUME_DB)
		_step_idx = (_step_idx + 1) % _snow_streams.size()

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var running := Input.is_physical_key_pressed(KEY_SHIFT)
	velocity.x = direction * (RUN_SPEED if running else WALK_SPEED)

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
			# У Examinable свой собственный глаз (висит всегда, ярчает вблизи) —
			# общий промпт показываем только для дверей/тайников/предметов.
			if collider.get_interaction_type() == Interactable.Type.EXAMINABLE:
				prompt.visible = false
			else:
				prompt.global_position = collider.global_position + Vector2(0, -72)
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
			# Поглощаем нажатие, чтобы то же событие E не долетело до
			# note_popup/dialogue_box и не закрыло/не пролистнуло только что
			# открытое окно той же клавишей.
			get_viewport().set_input_as_handled()
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
