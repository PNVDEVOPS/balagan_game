class_name Flashlight
extends PointLight2D

signal charge_depleted()
signal qte_success()
signal qte_failure()

const MAX_CHARGE := 100.0
const DRAIN_RATE := 0.0
const CRANK_AMOUNT := 8.0
const QTE_DRAIN_RATE := 15.0
const QTE_CHARGE_PER_PRESS := 6.0
const QTE_THRESHOLD := 80.0
const QTE_TIMEOUT := 4.0
const LOW_CHARGE := 30.0
const FLICKER_CHANCE := 0.3
const BOOST_DRAIN_RATE := 7.0
const BOOST_ENERGY_MULTIPLIER := 3.5
const BOOST_SCALE_MULTIPLIER := 2.2

var charge: float = MAX_CHARGE
var is_cranking: bool = false
var is_scripted_off: bool = false
var is_qte_active: bool = false
var is_boost_active: bool = false
var qte_timer: float = 0.0

var _base_energy: float = 2.8
var _base_scale: float = 2.0
var _flicker_timer: float = 0.0
var _base_x: float = 0.0

func _ready() -> void:
	_base_x = position.x
	_generate_cone_texture()
	texture_scale = _base_scale
	energy = _base_energy
	if not Inventory.has_item("flashlight"):
		is_scripted_off = true
		energy = 0.0

func _generate_cone_texture() -> void:
	# 128x128 image — cone pointing RIGHT from center
	# Sharp triangular edges, 18° half-angle
	const IMG := 128
	const HALF_F := float(IMG) / 2.0
	const MAX_D := HALF_F * 1.8         # how far the beam reaches
	const COS_HALF := 0.766             # cos(40°) — wide beam

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
	scale.x = 1.0 if facing_right else -1.0
	position.x = _base_x if facing_right else -_base_x

func _process(delta: float) -> void:
	if is_scripted_off:
		energy = 0.0
		return

	if is_qte_active:
		_process_qte(delta)
		return

	if is_boost_active:
		charge = maxf(charge - BOOST_DRAIN_RATE * delta, 0.0)
		if charge <= 0.0:
			is_boost_active = false
	elif not is_cranking:
		charge = maxf(charge - DRAIN_RATE * delta, 0.0)

	_update_visuals(delta)

	if charge <= 0.0:
		charge_depleted.emit()

func _process_qte(delta: float) -> void:
	qte_timer -= delta
	charge = maxf(charge - QTE_DRAIN_RATE * delta, 0.0)
	_update_visuals(delta)

	if charge >= QTE_THRESHOLD:
		is_qte_active = false
		charge = MAX_CHARGE
		energy = _base_energy * 3.0
		var tween := create_tween()
		tween.tween_property(self, "energy", _base_energy, 0.5)
		qte_success.emit()
		return

	if qte_timer <= 0.0 or charge <= 0.0:
		is_qte_active = false
		qte_failure.emit()

func _update_visuals(delta: float) -> void:
	var charge_ratio := charge / MAX_CHARGE
	if is_boost_active and charge > 0.0:
		energy = _base_energy * BOOST_ENERGY_MULTIPLIER
		texture_scale = _base_scale * BOOST_SCALE_MULTIPLIER
	else:
		energy = _base_energy * charge_ratio
		texture_scale = _base_scale * (0.65 + 0.35 * charge_ratio)
		if charge < LOW_CHARGE:
			_flicker_timer -= delta
			if _flicker_timer <= 0.0:
				_flicker_timer = randf_range(0.1, 0.4)
				if randf() < FLICKER_CHANCE:
					energy *= randf_range(0.2, 0.8)

func activate_boost() -> void:
	if is_scripted_off or is_qte_active:
		return
	is_boost_active = true
	is_cranking = false

func deactivate_boost() -> void:
	is_boost_active = false

# Backward-compatible aliases (player.gd calls these)
func crank() -> void:
	activate_boost()

func stop_crank() -> void:
	deactivate_boost()

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
