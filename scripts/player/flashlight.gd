class_name Flashlight
extends PointLight2D

signal charge_depleted()
signal qte_success()
signal qte_failure()

const MAX_CHARGE := 100.0
const PUMP_PER_PRESS := 34.0    # +за каждое нажатие F (≈3 нажатия до пика)
const PUMP_DECAY := 55.0        # спад мощности в секунду без нажатий
const PEAK_CHARGE := 80.0       # с этого уровня включается пик (boost)
const PEAK_RELEASE := 45.0      # ниже этого — пик гаснет (гистерезис, чтобы не дёргалось)

const QTE_DRAIN_RATE := 15.0
const QTE_CHARGE_PER_PRESS := 6.0
const QTE_THRESHOLD := 80.0
const QTE_TIMEOUT := 4.0

const BOOST_ENERGY_MULTIPLIER := 3.5
const BOOST_SCALE_MULTIPLIER := 2.2

# Лампа: радиальный тёплый свет, мерцающий как огонь
const LAMP_TEX    := "res://assets/sprites/light_gradient.png"
const LAMP_COLOR  := Color(1.0, 0.66, 0.36)
const LAMP_SCALE  := 3.0
const LAMP_ENERGY := 1.7

enum LightKind { FLASHLIGHT, LAMP, DARK }

# charge = уровень накачки 0..MAX. 0 — обычный свет, MAX — пиковая мощность.
var charge: float = 0.0
var is_scripted_off: bool = false
var is_qte_active: bool = false
var is_boost_active: bool = false   # пиковая мощность (с гистерезисом)
var qte_timer: float = 0.0

var _kind: LightKind = LightKind.FLASHLIGHT
var _fire_phase: float = 0.0
var _base_energy: float = 2.8
var _base_scale: float = 2.0
var _base_x: float = 0.0

func _ready() -> void:
	_base_x = position.x
	_generate_cone_texture()
	texture_scale = _base_scale
	energy = _base_energy
	_resolve_kind()
	_apply_kind()

# Какой свет сейчас: фонарь / лампа / темнота
func _resolve_kind() -> void:
	if Inventory.has_item("oil_lamp"):
		_kind = LightKind.LAMP
	elif not Inventory.has_item("flashlight"):
		_kind = LightKind.DARK
	elif GameManager.lamp_needed:
		_kind = LightKind.DARK   # после dark_c2 обычный фонарь не работает, пока нет лампы
	else:
		_kind = LightKind.FLASHLIGHT

func _apply_kind() -> void:
	match _kind:
		LightKind.LAMP:
			if ResourceLoader.exists(LAMP_TEX):
				texture = load(LAMP_TEX)
			color         = LAMP_COLOR
			texture_scale = LAMP_SCALE
			position.x    = 0.0
			scale.x       = 1.0
			energy        = LAMP_ENERGY
		LightKind.DARK:
			energy = 0.0
		_:
			color  = Color(1.0, 0.957, 0.839)
			energy = _base_energy

func _generate_cone_texture() -> void:
	# 128x128 image — cone pointing RIGHT from center
	# Sharp triangular edges, 18° half-angle
	const IMG := 128
	const HALF_F := float(IMG) / 2.0
	const MAX_D := HALF_F * 0.75        # how far the beam reaches
	const COS_HALF := 0.9511            # cos(18°)

	var image := Image.create(IMG, IMG, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	for y in range(IMG):
		for x in range(IMG):
			var dx := float(x) - HALF_F
			var dy := float(y) - HALF_F

			if dx <= 0.0:
				continue

			var dist := sqrt(dx * dx + dy * dy)
			if dist < 0.5 or dist > MAX_D:
				continue

			var cos_a := dx / dist          # cosine of angle from rightward axis
			if cos_a < COS_HALF:
				continue

			# Linear brightness falloff along the beam length; sharp angular edges
			var brightness := 1.0 - dist / MAX_D
			# Tiny soft fringe at the tip (makes it feel less harsh)
			if dist < 6.0:
				brightness = 1.0
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, brightness))

	texture = ImageTexture.create_from_image(image)

func set_facing(facing_right: bool) -> void:
	if _kind == LightKind.LAMP:
		scale.x = 1.0      # лампа светит вокруг, не флипаем
		position.x = 0.0
		return
	scale.x = 1.0 if facing_right else -1.0
	position.x = _base_x if facing_right else -_base_x

func _process(delta: float) -> void:
	if is_scripted_off:
		energy = 0.0
		return

	if _kind == LightKind.DARK:
		energy = 0.0
		return

	if _kind == LightKind.LAMP:
		_process_lamp(delta)
		return

	if is_qte_active:
		_process_qte(delta)
		return

	# Накачка спадает со временем — без нажатий свет возвращается к обычному.
	charge = maxf(charge - PUMP_DECAY * delta, 0.0)
	_update_peak_state()
	_update_visuals()

# Лампа: яркость «дышит» как живой огонь
func _process_lamp(delta: float) -> void:
	_fire_phase += delta
	var flick := 0.85 + 0.12 * sin(_fire_phase * 8.0) + randf_range(-0.05, 0.05)
	energy = LAMP_ENERGY * clampf(flick, 0.6, 1.15)

func _process_qte(delta: float) -> void:
	qte_timer -= delta
	charge = maxf(charge - QTE_DRAIN_RATE * delta, 0.0)
	_update_visuals()

	if charge >= QTE_THRESHOLD:
		is_qte_active = false
		charge = MAX_CHARGE
		qte_success.emit()
		return

	if qte_timer <= 0.0 or charge <= 0.0:
		is_qte_active = false
		qte_failure.emit()

# Гистерезис: пик включается на PEAK_CHARGE, держится до падения ниже PEAK_RELEASE.
# Так мелкие провалы между нажатиями не дёргают свет вкл/выкл.
func _update_peak_state() -> void:
	if charge >= PEAK_CHARGE:
		is_boost_active = true
	elif charge < PEAK_RELEASE:
		is_boost_active = false

func _update_visuals() -> void:
	var ratio := charge / MAX_CHARGE
	energy        = _base_energy * (1.0 + ratio * (BOOST_ENERGY_MULTIPLIER - 1.0))
	texture_scale = _base_scale  * (1.0 + ratio * (BOOST_SCALE_MULTIPLIER - 1.0))

# Одно нажатие F — толчок мощности вверх.
func pump() -> void:
	if is_scripted_off or is_qte_active:
		return
	charge = minf(charge + PUMP_PER_PRESS, MAX_CHARGE)
	_update_peak_state()

func deactivate_boost() -> void:
	charge = 0.0
	is_boost_active = false

# Backward-compatible aliases (player.gd / room logic call these)
func crank() -> void:
	pump()

func stop_crank() -> void:
	pass

func qte_press() -> void:
	if is_qte_active:
		charge = minf(charge + QTE_CHARGE_PER_PRESS, MAX_CHARGE)

func start_qte() -> void:
	is_qte_active = true
	charge = 10.0
	qte_timer = QTE_TIMEOUT

func scripted_off() -> void:
	is_scripted_off = true
	energy = 0.0

func scripted_on() -> void:
	is_scripted_off = false

func scripted_flicker(duration: float = 2.0) -> void:
	is_scripted_off = true
	var elapsed := 0.0
	while elapsed < duration:
		energy = randf_range(0.0, _base_energy * 0.5)
		var wait := randf_range(0.05, 0.15)
		await get_tree().create_timer(wait).timeout
		elapsed += wait
	is_scripted_off = false
