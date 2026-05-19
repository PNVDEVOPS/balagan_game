extends Control

func _ready() -> void:
	$Panel/ResumeBtn.pressed.connect(_on_resume)
	$Panel/SaveBtn.pressed.connect(_on_save)
	$Panel/MainMenuBtn.pressed.connect(_on_main_menu)

func _on_resume() -> void:
	hide()
	get_tree().paused = false

func _on_save() -> void:
	SaveManager.save()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
