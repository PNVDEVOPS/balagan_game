extends Node2D

var _cradle_minigame_active: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("doll"):
		for node_name in ["KeyPickable", "ChestDoll", "DollPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	# Cradle riddle note
	var riddle := get_node_or_null("RiddleCradle")
	if not riddle:
		riddle = get_node_or_null("RiddleBishik")
	if riddle:
		riddle.examined.connect(func():
			DialogueManager.start_dialogue("notes/riddle_cradle")
			GameManager.mark_note_found("riddle_cradle")
		)

	# Cradle interaction — launches minigame
	var cradle := get_node_or_null("Cradle")
	if not cradle:
		cradle = get_node_or_null("Bishik")
	if cradle:
		cradle.examined.connect(_on_cradle_examined)

	var chest := get_node_or_null("ChestDoll")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.picked_up.connect(func(_id): _on_doll_picked_up())

	# Mother diary notes (4 entries)
	for note_data: Array in [
			["NoteMother1", "notes/note_mother_1", "note_mother_1"],
			["NoteMother2", "notes/note_mother_2", "note_mother_2"],
			["NoteMother3", "notes/note_mother_3", "note_mother_3"],
			["NoteMother4", "notes/note_mother_4", "note_mother_4"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		var note_id: String = note_data[2]
		if note:
			note.examined.connect(func():
				DialogueManager.start_dialogue(key)
				GameManager.mark_note_found(note_id)
			)

	# Кыдаана note 3 — with fallback for old node name
	var kydaana3 := get_node_or_null("NoteKydaana3")
	if not kydaana3:
		kydaana3 = get_node_or_null("NoteAiyyna3")
	if kydaana3:
		kydaana3.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_3")
			GameManager.mark_note_found("note_kydaana_3")
		)

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and GameManager.artifacts_collected.has("doll"):
				GameManager.change_room("door_forward")
		)

	var cradle_sub := get_node_or_null("BedExamine")
	if cradle_sub and not GameManager.artifacts_collected.has("doll"):
		cradle_sub.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Здесь я видела сны. Хорошие — в начале.",
				SubtitleManager.Pos.TOP_CENTER
			)
		, CONNECT_ONE_SHOT)

func _on_cradle_examined() -> void:
	if _cradle_minigame_active:
		return
	DialogueManager.show_text("", "Загадка нацарапана над колыбелью.")
	await DialogueManager.dialogue_finished
	DialogueManager.start_dialogue("notes/riddle_cradle")
	await DialogueManager.dialogue_finished
	_launch_cradle_minigame()

func _launch_cradle_minigame() -> void:
	_cradle_minigame_active = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()

	var scene := preload("res://scenes/minigames/minigame_cradle.tscn")
	var mg: MinigameCradle = scene.instantiate()
	get_tree().current_scene.add_child(mg)
	mg.minigame_completed.connect(_on_cradle_solved)
	mg.minigame_cancelled.connect(_on_cradle_cancelled)

func _on_cradle_solved(_id: String) -> void:
	_cradle_minigame_active = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
	DialogueManager.show_text("", "Колыбель качнулась сама. Тихий звук — будто кто-то напевает. Под подушкой что-то блеснуло.")
	await DialogueManager.dialogue_finished
	var key := get_node_or_null("KeyPickable")
	if key:
		key.visible = true
		key.set_deferred("monitoring", true)

func _on_cradle_cancelled() -> void:
	_cradle_minigame_active = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func _on_chest_used() -> void:
	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.visible = true
		doll.set_deferred("monitoring", true)

func _on_doll_picked_up() -> void:
	GameManager.collect_artifact("doll")
	_trigger_flashback()

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
	DialogueManager.start_dialogue("notes/artifact_doll")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
