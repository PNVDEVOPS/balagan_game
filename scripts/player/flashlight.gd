extends PointLight2D

signal charge_depleted()
signal qte_success()
signal qte_failure()

const MAX_CHARGE := 100.0
const DRAIN_RATE := 2.2
const CRANK_AMOUNT := 8.0
const QTE_DRAIN_RATE := 15.0
const QTE_CHARGE_PER_PRESS := 6.0
const QTE_THRESHOLD := 80.0
const QTE_TIMEOUT := 4.0
const LOW_CHARGE := 30.0
const FLICKER_CHANCE := 0.3

var charge: float = MAX_CHARGE
var is_cranking: bool = false
var is_scripted_off: bool = false
var is_qte_active: bool = false
var qte_timer: float = 0.0

var _base_energy: float = 1.5
var _base_scale: float = 2.0
var _flicker_timer: float = 0.0

func _process(delta: float) -> void:
	if is_scripted_off:
		energy = 0.0
		return

	if is_qte_active:
		_process_qte(delta)
		return

	if not is_cranking:
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
	energy = _base_energy * charge_ratio
	texture_scale = _base_scale * (0.5 + 0.5 * charge_ratio)

	if charge < LOW_CHARGE:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.1, 0.4)
			if randf() < FLICKER_CHANCE:
				energy *= randf_range(0.2, 0.8)

func crank() -> void:
	if is_scripted_off or is_qte_active:
		return
	is_cranking = true
	charge = minf(charge + CRANK_AMOUNT, MAX_CHARGE)

func stop_crank() -> void:
	is_cranking = false

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
