extends Node2D

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var homuz := get_node_or_null("HomuzExaminable")
	if homuz:
		homuz.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Мать играла каждый вечер. Я засыпала под него.",
				SubtitleManager.Pos.BOTTOM_CENTER
			)
		)

	var table := get_node_or_null("TableExaminable")
	if table:
		table.examined.connect(func():
			DialogueManager.show_text("", "Тарелки на двоих. Еда остыла, но не заветрела — ушли недавно. Или не ушли.\n\nЧашка у края стола перевёрнута. Чай разлился и высох.\n\nНа краю — тетрадь. Чужой почерк.")
			await DialogueManager.dialogue_finished
			for key: String in ["note_mother_1", "note_mother_2", "note_mother_3"]:
				GameManager.mark_note_found(key)
				DialogueManager.start_dialogue("notes/" + key)
				await DialogueManager.dialogue_finished
		)

	# WindowExamine показывает только свой inline examine_text (атмосфера)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Мы ели здесь все вместе. Давно.",
		SubtitleManager.Pos.BOTTOM_LEFT
	)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
