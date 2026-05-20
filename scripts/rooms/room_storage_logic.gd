extends Node2D

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var bags := get_node_or_null("BagsExaminable")
	if bags:
		bags.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Отец считал их каждую ночь. Думал — я не вижу.",
				SubtitleManager.Pos.BOTTOM_LEFT
			)
		)

	var note_env3 := get_node_or_null("NoteEnv3")
	if note_env3:
		note_env3.examined.connect(func():
			GameManager.mark_note_found("note_env_3")
			DialogueManager.start_dialogue("notes/note_env_3")
		)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Запасов хватило бы до весны. Но весны не было.",
		SubtitleManager.Pos.TOP_CENTER
	)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
