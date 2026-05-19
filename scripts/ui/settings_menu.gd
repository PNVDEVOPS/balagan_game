extends Control

const SETTINGS_PATH := "user://settings.json"

func _ready() -> void:
	_load_settings()
	$VBox/VolumeSlider.value_changed.connect(_on_volume_changed)
	$VBox/FullscreenCheck.toggled.connect(_on_fullscreen_toggled)
	$VBox/BackBtn.pressed.connect(_on_back_pressed)

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _save_settings() -> void:
	var data := {
		"volume": $VBox/VolumeSlider.value,
		"fullscreen": $VBox/FullscreenCheck.button_pressed
	}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		$VBox/VolumeSlider.value = 1.0
		$VBox/FullscreenCheck.button_pressed = false
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return
	file.close()
	var data: Dictionary = json.data
	var vol: float = float(data.get("volume", 1.0))
	$VBox/VolumeSlider.value = vol
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(vol))
	var fs: bool = bool(data.get("fullscreen", false))
	$VBox/FullscreenCheck.button_pressed = fs
	if fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
