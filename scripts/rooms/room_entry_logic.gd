extends Node2D

static var _back_trigger_count: int = 0

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1280

	var exit_door := get_node_or_null("ExitDoorZone")
	if exit_door:
		exit_door.body_entered.connect(_on_exit_door)

	var forward := get_node_or_null("ForwardZone")
	if forward:
		forward.body_entered.connect(_on_forward_zone)

	var note := get_node_or_null("NoteEntry1")
	if note:
		note.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_env_hunting")
			GameManager.mark_note_found("note_env_hunting")
		)

	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)

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

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
