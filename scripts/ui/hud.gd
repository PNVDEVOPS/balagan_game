extends CanvasLayer

var _save_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.saved.connect(_on_saved)
	$SavedLabel.visible = false

func _process(delta: float) -> void:
	if _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			$SavedLabel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pm: Control = $PauseMenu
		if pm.visible:
			pm.hide()
			get_tree().paused = false
		else:
			pm.show()
			get_tree().paused = true
		get_viewport().set_input_as_handled()

func show_hint(text: String) -> void:
	$InteractHint.text = "[E]   " + text
	$InteractHint.visible = true

func hide_hint() -> void:
	$InteractHint.visible = false

func set_darkness(alpha: float) -> void:
	$DarkOverlay.color.a = clampf(alpha, 0.0, 1.0)

func _on_saved() -> void:
	$SavedLabel.visible = true
	_save_timer = 2.0
