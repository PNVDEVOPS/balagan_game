extends Node2D

static var _back_trigger_count: int = 0

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

	var note_env := get_node_or_null("NoteEnv3")
	if note_env:
		note_env.examined.connect(func():
			GameManager.mark_note_found("note_env_4")
			DialogueManager.start_dialogue("notes/note_env_4")
		)

	for note_data: Array in [
			["NoteKydaana4", "notes/note_kydaana_4", "note_kydaana_4"],
			["NoteKydaana3", "notes/note_kydaana_3", "note_kydaana_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		var note_id: String = note_data[2]
		if note:
			note.examined.connect(func():
				GameManager.mark_note_found(note_id)
				DialogueManager.start_dialogue(key)
			)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Запасов хватило бы до весны. Но весны не было.",
		SubtitleManager.Pos.TOP_CENTER
	)

	_add_back_zone()

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
