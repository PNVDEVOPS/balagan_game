extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var prompt_label: Label = $Panel/VBoxContainer/PromptLabel
@onready var charge_bar: ProgressBar = $Panel/VBoxContainer/ChargeBar

var flashlight_ref: Node = null
var shake_intensity: float = 0.0

func _ready() -> void:
	panel.visible = false
	add_to_group("qte_overlay")

func start_qte(flashlight: Node) -> void:
	flashlight_ref = flashlight
	panel.visible = true
	prompt_label.text = "[ E ] [ E ] [ E ]"
	charge_bar.max_value = 100.0
	shake_intensity = 3.0
	flashlight.qte_success.connect(_on_qte_end.bind(true), CONNECT_ONE_SHOT)
	flashlight.qte_failure.connect(_on_qte_end.bind(false), CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
	if not panel.visible or not flashlight_ref:
		return
	charge_bar.value = flashlight_ref.charge
	if shake_intensity > 0:
		panel.position = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

func _on_qte_end(_success: bool) -> void:
	panel.visible = false
	flashlight_ref = null
	shake_intensity = 0.0
	panel.position = Vector2.ZERO
