extends Control

func _ready() -> void:
	$Buttons/ContinueBtn.disabled = not SaveManager.has_save()
	$Buttons/NewGameBtn.pressed.connect(_on_new_game_pressed)
	$Buttons/ContinueBtn.pressed.connect(_on_continue_pressed)
	$Buttons/SettingsBtn.pressed.connect(_on_settings_pressed)
	$Buttons/QuitBtn.pressed.connect(_on_quit_pressed)

func _on_new_game_pressed() -> void:
	_disable_buttons()
	SaveManager.delete_save()
	GameManager.artifacts_collected.clear()
	Inventory.items.clear()
	Inventory.selected_item = ""
	GameManager.transition_count = 0
	GameManager._load_room_graph()
	ChapterManager.current_chapter = ChapterManager.Chapter.ROAD
	ChapterManager.start_chapter(ChapterManager.Chapter.ROAD)

func _on_continue_pressed() -> void:
	_disable_buttons()
	if SaveManager.load_game():
		var scene_path := GameManager.get_room_scene(GameManager.current_room)
		if scene_path.is_empty():
			scene_path = "res://scenes/rooms/room_main_hall.tscn"
		get_tree().change_scene_to_file(scene_path)
	else:
		_enable_buttons()

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _disable_buttons() -> void:
	for btn in $Buttons.get_children():
		btn.disabled = true

func _enable_buttons() -> void:
	$Buttons/NewGameBtn.disabled = false
	$Buttons/ContinueBtn.disabled = not SaveManager.has_save()
	$Buttons/SettingsBtn.disabled = false
	$Buttons/QuitBtn.disabled = false
