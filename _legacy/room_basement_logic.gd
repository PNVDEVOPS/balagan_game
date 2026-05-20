extends Node2D

var _mirror_minigame_active: bool = false
var _mirror_solved: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		for node_name in ["KeyPickable", "ChestEarring", "EarringPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		var door := get_node_or_null("DoorForestPath")
		if door:
			door.visible = true
			door.set_deferred("monitoring", true)
		return

	var riddle := get_node_or_null("RiddleMirror")
	if riddle:
		riddle.examined.connect(func():
			DialogueManager.start_dialogue("notes/riddle_mirror")
			GameManager.mark_note_found("riddle_mirror")
		)

	var mirror := get_node_or_null("OldMirror")
	if mirror:
		mirror.examined.connect(_on_mirror_examined)

	var chest := get_node_or_null("ChestEarring")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): _on_earring_picked_up())

	# Кыдаана note 5 — with fallback for old node name
	var kydaana5 := get_node_or_null("NoteKydaana5")
	if not kydaana5:
		kydaana5 = get_node_or_null("NoteAiyyna5")
	if kydaana5:
		kydaana5.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_5")
			GameManager.mark_note_found("note_kydaana_5")
		)

	# Кыдаана note 4 (бык)
	var kydaana4 := get_node_or_null("NoteKydaana4")
	if kydaana4:
		kydaana4.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_4")
			GameManager.mark_note_found("note_kydaana_4")
		)

func _on_mirror_examined() -> void:
	if _mirror_minigame_active:
		return
	if _mirror_solved:
		DialogueManager.show_text("", "Зеркало собрано. Ты помнишь — третья доска от окна, где сучок звездой.")
		return
	DialogueManager.start_dialogue("notes/riddle_mirror")
	await DialogueManager.dialogue_finished
	_launch_mirror_minigame()

func _launch_mirror_minigame() -> void:
	_mirror_minigame_active = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()
	var scene := preload("res://scenes/minigames/minigame_mirror.tscn")
	var mg: MinigameMirror = scene.instantiate()
	get_tree().current_scene.add_child(mg)
	mg.minigame_completed.connect(_on_mirror_solved_signal)
	mg.minigame_cancelled.connect(_on_mirror_cancelled)

func _on_mirror_solved_signal(_id: String) -> void:
	_mirror_minigame_active = false
	_mirror_solved = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
	DialogueManager.show_text("", "Зеркало собралось. В нём — отражение другого подвала. Там, где сучок в доске похож на звезду, что-то спрятано.")
	await DialogueManager.dialogue_finished
	var floorboard := get_node_or_null("SecretFloorboard")
	if floorboard:
		floorboard.visible = true
		floorboard.set_deferred("monitoring", true)

func _on_mirror_cancelled() -> void:
	_mirror_minigame_active = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func _on_chest_used() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_unlock_forest_path()
	_trigger_flashback()

func _unlock_forest_path() -> void:
	var door := get_node_or_null("DoorForestPath")
	if door:
		door.visible = true
		door.set_deferred("monitoring", true)

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_earring")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
