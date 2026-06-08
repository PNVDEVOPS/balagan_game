extends Node2D

# Две тёмные комнаты — две механики:
#   dark_c1 — тьма наползает спереди, рассеивается накачкой фонаря (спам F).
#   dark_c2 — гейт масляной лампы:
#       без лампы → Кыдаана гонит назад, фонарь гаснет («нужен свет»);
#       с лампой  → тьма расступается, проход свободен вперёд.

const DARKNESS_SPEED  := 72.0    # быстрее наползает (было 45)
const START_X_RIGHT   := 1700.0
const ROOM_WIDTH      := 1600.0
const SHAKE_PROXIMITY  := 380.0
const ZOOM_MAX        := 1.12
const BOOST_REQUIRED  := 2.4     # чуть быстрее рассеивается под напором света
const EDGE_WIDTH      := 200.0   # ширина зоны осыпания у фронта — меньше = короче языки, виднее чёрное основание
const RETREAT_SPEED   := 80.0    # тьма гонит игрока назад (dark_c2 без лампы)
# Сопротивление свету: тьма не плавно отходит, а толкается рывками против фонаря.
const RESIST_RECEDE   := 60.0    # средний откат фронта под буст-светом
const RESIST_PUSH     := 95.0    # сила рывка тьмы вперёд (в пике толчка)
# «Несколько шагов от входа» — на этой дистанции от точки входа звучит реплика
# и тьма оживает (dark_c1). Тьма при этом стоит справа с самого начала.
const STEPS_DIST      := 200.0
# dark_c2: фронт тьмы стоит почти у конца комнаты; оживает, когда игрок прошёл середину.
const DARK_C2_FRONT   := ROOM_WIDTH - 160.0

# Визуал стены тьмы — шейдер на ColorRect (рваный осыпающийся фронт справа->налево).
const DARK_SHADER     := "res://assets/shaders/wall_of_darkness.gdshader"
const DARK_BODY_WIDTH := 2400.0  # сплошное тело тьмы вправо от фронта
const DARK_HEIGHT     := 490.0   # от -60 до 430 по Y
const DARK_TOP        := -60.0

# Усиление виньетки и плёночного шума по мере приближения тьмы (как зум/шейк).
const OVERLAY_PROXIMITY := 600.0 # дистанция, на которой эффект начинает нарастать
const VIGNETTE_BASE   := 0.38    # дефолт из hud.tscn
const VIGNETTE_MAX    := 0.90    # мягче — чтобы не сливалось с чёрной стеной
# Шум у тьмы НЕ нарастает (перекрывал саму тьму) — зерно держим постоянным.

var _mode: String = "dispel"     # "dispel" | "lamp_pass" | "lamp_retreat"

var _darkness:        ColorRect
var _vignette_mat:    ShaderMaterial
var _grain_mat:       ShaderMaterial
var _darkness_x:      float   = START_X_RIGHT
var _active:          bool    = false
var _defeated:        bool    = false
var _penalty_done:    bool    = false
var _shake_time:      float   = 0.0
var _pulse_time:      float   = 0.0
var _base_zoom:       Vector2 = Vector2.ONE
var _boost_hold_time: float   = 0.0
var _entrance_x:      float   = 0.0     # x точки входа (записывается после расстановки)
var _intro_armed:     bool    = false   # игрок расставлен, ждём «несколько шагов» (dispel)
var _intro_started:   bool    = false   # интро-реплика уже запущена

func _ready() -> void:
	var is_c2 := GameManager.current_room == "dark_c2"
	if GameManager.spawn_door_id == "door_back":
		_mode = "free_pass"                          # вошёл справа (возврат) — тихо, без реплик
	elif Inventory.has_item("oil_lamp"):
		_mode = "lamp_pass"                          # лампа держит тьму
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
	_cache_overlays()

	# dark_c1: тьма далеко справа (START_X_RIGHT), наползает после реплики «через шаги».
	# dark_c2: тьма стоит почти у конца комнаты и оживает, когда игрок прошёл середину.
	match _mode:
		"lamp_pass":
			_setup_lamp_pass()
		"free_pass":
			pass                                     # просто проходим, тихо
		"lamp_retreat":
			_build_darkness()
			_darkness_x = DARK_C2_FRONT              # тьма уже выступает у конца комнаты
			_sync_positions()
			_arm_intro()
		_:
			_build_darkness()
			_arm_intro()

# ── общая тьма: один ColorRect с шейдером, рваный фронт слева ───────────
# Тело тянется вправо от фронта, шейдер сам осыпает левый край.
func _build_darkness() -> void:
	var total_w := EDGE_WIDTH + DARK_BODY_WIDTH

	_darkness = ColorRect.new()
	_darkness.size         = Vector2(total_w, DARK_HEIGHT)
	_darkness.position     = Vector2(0, DARK_TOP)
	_darkness.color        = Color(1, 1, 1, 1)   # итоговый цвет полностью задаёт шейдер
	_darkness.z_index      = 50
	_darkness.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = load(DARK_SHADER)
	mat.set_shader_parameter("rect_size", Vector2(total_w, DARK_HEIGHT))
	mat.set_shader_parameter("front_pos", EDGE_WIDTH / total_w)  # фронт по UV = игровой _darkness_x
	_darkness.material = mat

	add_child(_darkness)
	_sync_positions()

func _sync_positions() -> void:
	# Левый край ColorRect = фронт минус зона осыпания; шейдерный фронт ложится на _darkness_x.
	if _darkness:
		_darkness.position.x = _darkness_x - EDGE_WIDTH

# ── оверлеи HUD: виньетка + плёночный шум усиливаются у фронта ──────────
func _cache_overlays() -> void:
	var hud := get_node_or_null("HUD")
	if not hud:
		return
	var v := hud.get_node_or_null("Vignette")
	var g := hud.get_node_or_null("Grain")
	# Дублируем материал, чтобы менять силу только в этой комнате (не трогая общий ресурс).
	if v and v.material is ShaderMaterial:
		_vignette_mat = v.material.duplicate()
		v.material = _vignette_mat
	if g and g.material is ShaderMaterial:
		_grain_mat = g.material.duplicate()
		g.material = _grain_mat

# t по дистанции до фронта: 0 далеко, 1 вплотную. Тянем только виньетку, шум не трогаем.
func _drive_overlays(dist: float) -> void:
	var t := clampf(1.0 - dist / OVERLAY_PROXIMITY, 0.0, 1.0)
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("strength", lerpf(VIGNETTE_BASE, VIGNETTE_MAX, t))

func _reset_overlays() -> void:
	if _vignette_mat:
		_vignette_mat.set_shader_parameter("strength", VIGNETTE_BASE)

# Ждём, пока игрока расставят на точку входа и закончится fade, затем «взводим»
# триггер. Реплика звучит в _process: dark_c1 — по шагам, dark_c2 — за серединой.
func _arm_intro() -> void:
	await get_tree().create_timer(0.35).timeout
	var player := get_node_or_null("Player")
	if player:
		_entrance_x = player.global_position.x
	_intro_armed = true

func _start_dispel_intro() -> void:
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	if flashlight and flashlight.has_method("scripted_flicker"):
		flashlight.scripted_flicker(0.8)
	await get_tree().create_timer(0.3).timeout
	DialogueManager.show_text("", "Что-то приближается.")
	await DialogueManager.dialogue_finished
	_active = true                                   # тьма оживает и наползает

# ── dark_c2 без лампы: Кыдаана гонит назад, фонарь гаснет ───────────────
# Тьма стоит у конца комнаты; когда игрок проходит середину — Кыдаана и погоня.
# «Фонарик сдох» уезжает на выход (показывается в entry_c3).
func _start_retreat_intro() -> void:
	_intro_started = true
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	# Дожидаемся мигания (оно само включает фонарь в конце), потом гасим насовсем
	if flashlight and flashlight.has_method("scripted_flicker"):
		await flashlight.scripted_flicker(0.7)
	if flashlight and flashlight.has_method("scripted_off"):
		flashlight.scripted_off()
	DialogueManager.show_text("Кыдаана", "Уходи.")
	await DialogueManager.dialogue_finished
	GameManager.lamp_needed = true
	_active = true                                   # тьма гонит игрока назад

# ── dark_c2 с лампой: тьма расступается, иди вперёд ─────────────────────
func _setup_lamp_pass() -> void:
	await get_tree().create_timer(0.4).timeout
	SubtitleManager.show_subtitle("Лампа держит тьму на расстоянии.", SubtitleManager.Pos.BOTTOM_CENTER)

func _process(delta: float) -> void:
	if _defeated or _penalty_done:
		return
	var player := get_node_or_null("Player")
	if not player:
		return
	# Тьма ещё не активна. dark_c1 ждёт «несколько шагов» от входа; dark_c2 ждёт,
	# пока игрок пройдёт середину — тогда тьма у конца комнаты оживает и гонит назад.
	if not _active:
		if _intro_armed and not _intro_started:
			if _mode == "dispel" \
					and absf(player.global_position.x - _entrance_x) >= STEPS_DIST:
				_intro_started = true
				_start_dispel_intro()
			elif _mode == "lamp_retreat" \
					and player.global_position.x >= ROOM_WIDTH * 0.5:
				_intro_started = true
				_start_retreat_intro()
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
	_drive_overlays(dist)
	if dist <= 0.0:
		_penalty_done = true
		_active = false
		# Тьма настигла — снова в начало ЭТОЙ же комнаты (не отбрасывает назад).
		# Сообщение про фонарь — только при сознательном выходе влево (back-зона).
		GameManager.lamp_needed = true
		GameManager.change_room_direct(GameManager.current_room, "door_forward")

func _process_dispel(delta: float, player: Node) -> void:
	_pulse_time += delta
	var pulse: float = 0.5 + 0.5 * absf(sin(_pulse_time * PI * 1.1))

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_boost_hold_time += delta
		# Тьма сопротивляется свету: в среднем отступает, но толкается рывками вперёд.
		var jolt: float = maxf(0.0, sin(_boost_hold_time * 11.0))
		_darkness_x += (RESIST_RECEDE - RESIST_PUSH * jolt) * delta
		_sync_positions()
		var cam_r: Camera2D = player.get_node_or_null("Camera2D")
		if cam_r:
			_shake_time += delta * 30.0
			cam_r.offset = Vector2(sin(_shake_time) * 6.0 * jolt, sin(_shake_time * 0.6) * 4.0 * jolt)
		if _boost_hold_time >= BOOST_REQUIRED:
			_dispel_darkness(player)
		return
	else:
		_boost_hold_time = 0.0

	_darkness_x -= DARKNESS_SPEED * delta * pulse
	_sync_positions()
	# Пульсация/мерцание тьмы теперь в шейдере (TIME), вручную цвет не трогаем.

	var dist: float = _darkness_x - player.global_position.x
	_drive_overlays(dist)
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
	_reset_overlays()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_darkness, "position:x", START_X_RIGHT, 1.2)
	tween.tween_property(_darkness, "modulate:a", 0.0,           0.9)

func _trigger_penalty(player: Node) -> void:
	_penalty_done = true
	_active       = false
	_reset_camera(player)
	# Тьма настигла — возвращаемся в начало ЭТОЙ же комнаты, а не отбрасывает назад.
	GameManager.change_room_direct(GameManager.current_room, "door_forward")

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
			# Выход влево из dark_c2 без лампы → «Фонарик сдох…» в entry_c3
			if _mode == "lamp_retreat":
				GameManager.lamp_needed = true
				GameManager.pending_flashlight_dead = true
			GameManager.change_room("door_back")
	)

func _on_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if _mode == "lamp_retreat":
		return  # вперёд хода нет без света
	GameManager.change_room("door_forward")
