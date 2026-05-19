extends Node2D

func _ready() -> void:
	if GameManager.artifacts_collected.has("doll"):
		for node_name in ["KeyPickable", "ChestDoll", "DollPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	var riddle := get_node_or_null("RiddleBishik")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_bishik"))

	var bishik := get_node_or_null("Bishik")
	if bishik:
		bishik.examined.connect(_on_bishik_examined)

	var chest := get_node_or_null("ChestDoll")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.picked_up.connect(func(_id): _on_doll_picked_up())

	for note_data in [["NoteMother1", "notes/note_mother_1"], ["NoteMother2", "notes/note_mother_2"],
			["NoteMother3", "notes/note_mother_3"], ["NoteAiyyna3", "notes/note_aiyyna_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_bishik_examined() -> void:
	var key := get_node_or_null("KeyPickable")
	if key and not key.visible:
		DialogueManager.show_text("", "Пустая колыбель. Под покрывалом — что-то твёрдое.")
		await DialogueManager.dialogue_finished
		key.visible = true
		key.set_deferred("monitoring", true)
	else:
		DialogueManager.show_text("", "Колыбель качается сама. Без ребёнка. Без матери.")

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
