extends CanvasLayer

var _flashlight: Node = null
var _save_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.saved.connect(_on_saved)
	$SavedLabel.visible = false
	_find_flashlight()

func _find_flashlight() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_flashlight = player.get_node_or_null("Flashlight")

func _process(delta: float) -> void:
	if _flashlight == null:
		_find_flashlight()
	if _flashlight and _flashlight.has_method("get") and "charge" in _flashlight:
		$FlashlightBar.value = _flashlight.charge

	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			$SavedLabel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("ui_cancel"):
		var pm: Control = $PauseMenu
		if pm.visible:
			pm.hide()
			get_tree().paused = false
		else:
			pm.show()
			get_tree().paused = true
		get_viewport().set_input_as_handled()

func _on_saved() -> void:
	$SavedLabel.visible = true
	_save_timer = 2.0
