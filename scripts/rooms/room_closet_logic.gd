extends Node2D

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var kapkans := get_node_or_null("KapkansExaminable")
	if kapkans:
		kapkans.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Отец их больше не поднимет.",
				SubtitleManager.Pos.BOTTOM_CENTER
			)
			GameManager.mark_note_found("note_father_1")
			DialogueManager.start_dialogue("notes/note_father_1")
		)

	var chest := get_node_or_null("ChestExaminable")
	if chest:
		chest.examined.connect(func():
			GameManager.mark_note_found("note_father_2")
			DialogueManager.start_dialogue("notes/note_father_2")
		)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Ты не должен быть здесь.",
		SubtitleManager.Pos.MID_LEFT
	)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
