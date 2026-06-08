extends Node2D

static var _back_trigger_count: int = 0
# Реплика на самом первом входе в усадьбу — показывается один раз за сессию
static var _estate_intro_shown: bool = false

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

	# Масляная лампа: до тьмы — просто осмотр, после — её можно забрать.
	# Если лампа уже в руках/израсходована — убираем с полки и спрайт, и осмотр (глаз/[E]).
	var lamp := get_node_or_null("OilLampExaminable")
	var lamp_sprite := get_node_or_null("OilLampSprite")
	if Inventory.has_item("oil_lamp") or GameManager.kamylok_lit:
		if lamp_sprite:
			lamp_sprite.visible = false
		if lamp:
			lamp.queue_free()
	elif lamp:
		lamp.examined.connect(_on_oil_lamp_examined)

	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)
	elif not _estate_intro_shown:
		_estate_intro_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.show_text("", "Веет пустотой и холодом, мне тут не нравится.")

func _on_oil_lamp_examined() -> void:
	if Inventory.has_item("oil_lamp") or GameManager.kamylok_lit:
		DialogueManager.show_text("", "Лампа уже у меня.")
		return
	if GameManager.lamp_needed:
		# Тьма уже показала, что без света не пройти — забираем лампу
		Inventory.add_item("oil_lamp")
		# Прячем лампу с полки: и спрайт, и осмотр (глаз/[E])
		var lamp_sprite := get_node_or_null("OilLampSprite")
		if lamp_sprite:
			lamp_sprite.visible = false
		var lamp_exam := get_node_or_null("OilLampExaminable")
		if lamp_exam:
			lamp_exam.queue_free()
		# Сразу меняем спрайт игрока на «с лампой» и зажигаем тёплый свет лампы
		var player := get_node_or_null("Player")
		if player and player.has_method("refresh_appearance"):
			player.refresh_appearance()
		if player and player.flashlight_ctrl:
			player.flashlight_ctrl.scripted_on()
			player.flashlight_ctrl.refresh_kind()   # инвентарь изменился → свет = лампа сразу
		var lamp_tex: Texture2D = null
		var lamp_icon := "res://assets/sprites/items/lamp_hand.png"
		if ResourceLoader.exists(lamp_icon):
			lamp_tex = load(lamp_icon)
		ItemPopup.show_item(
			"Масляная лампа",
			"Старая, но целая.",
			lamp_tex)
		# Реплика-комментарий после попапа: свет лампы сдерживает тьму
		await get_tree().create_timer(2.5).timeout
		DialogueManager.show_text("", "Лампа не даёт тьме наступать.")
	else:
		DialogueManager.show_text("", "Старинная лампа. Как хорошо, что у меня есть фонарик — эта штука не пригодится.")

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Выход влево из усадьбы заблокирован — что-то держит внутри
	GameManager.escape_attempts += 1
	SubtitleManager.show_subtitle("Что-то не пускает меня обратно.", SubtitleManager.Pos.TOP_CENTER)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
