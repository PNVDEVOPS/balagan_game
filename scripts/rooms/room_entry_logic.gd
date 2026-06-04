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
			DialogueManager.start_dialogue("notes/note_kydaana_1")
			GameManager.mark_note_found("note_kydaana_1")
		)

	# Масляная лампа: до тьмы — просто осмотр, после — её можно забрать
	var lamp := get_node_or_null("OilLampExaminable")
	if lamp:
		lamp.examined.connect(_on_oil_lamp_examined)
	var lamp_sprite := get_node_or_null("OilLampSprite")
	if lamp_sprite and (Inventory.has_item("oil_lamp") or GameManager.kamylok_lit):
		lamp_sprite.visible = false  # уже забрана или израсходована

	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)

func _on_oil_lamp_examined() -> void:
	if Inventory.has_item("oil_lamp") or GameManager.kamylok_lit:
		DialogueManager.show_text("", "Лампа уже у меня.")
		return
	if GameManager.lamp_needed:
		# Тьма уже показала, что без света не пройти — забираем лампу
		Inventory.add_item("oil_lamp")
		var lamp_sprite := get_node_or_null("OilLampSprite")
		if lamp_sprite:
			lamp_sprite.visible = false
		ItemPopup.show_item(
			"Масляная лампа",
			"Старая, но целая. Если найти, чем зажечь, — даст настоящий свет.",
			null)
	else:
		DialogueManager.show_text("", "Довольно старинная лампа. Как хорошо, что у меня есть фонарь — эта штука не пригодится.")

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
