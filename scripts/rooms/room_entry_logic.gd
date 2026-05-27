extends Node2D

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

	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
