extends Node2D

var _window_examined: bool = false
var _laika_triggered: bool = false

func _ready() -> void:
	var room_id: String = GameManager.current_room

	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1600

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	if room_id == "entry_c3":
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)

	var window := get_node_or_null("WindowExamine")
	if window:
		_setup_window(window, room_id)

	var note := get_node_or_null("NoteCorr1")
	if note:
		_setup_note(note, room_id)

	if room_id == "entry_c4":
		var laika_trigger := get_node_or_null("LaikaTrigger")
		if laika_trigger:
			laika_trigger.body_entered.connect(_on_laika_trigger)

func _setup_window(window: Node, room_id: String) -> void:
	match room_id:
		"entry_c1":
			window.examine_text = "Двор занесло по пояс. Забор — едва угадывается. Где-то там загон, дровяник, тропинка к реке. Сейчас всё одно — белое."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Смотрю и жду, что появится хоть кто-то. Но снег ровный — ни следа, ни огня."
			)
		"entry_c2":
			window.examine_text = "Метель стихает. Небо чуть светлее у горизонта — не рассвет, просто луна за облаком."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Деревья стоят неподвижно. Как будто слушают."
			)
		"entry_c3":
			window.examine_text = "Тьма за стеклом такая плотная, что смотришь в неё — и кажется, что она смотрит обратно."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Там что-то есть. Или было. Я отошёл от окна."
			)
		"entry_c4":
			window.examine_text = "Дорога почти исчезла под снегом. Следы мои уже замело — будто я не приходил. Обратного пути нет."
		_:
			window.examine_text = "Темно за окном."

func _setup_note(note: Node, room_id: String) -> void:
	var note_key := ""
	match room_id:
		"entry_c1": note_key = "note_env_2"
		"corridor2": note_key = "note_father_4"
		"entry_c4":
			note_key = "note_haryshal"
			note.interaction_text = "Осмотреть записку на тумбе"
	if note_key.is_empty():
		note.queue_free()
		return
	note.examined.connect(func():
		DialogueManager.start_dialogue("notes/" + note_key)
		GameManager.mark_note_found(note_key)
	)

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_triggered:
		return
	_laika_triggered = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	DialogueManager.show_text("", "Опять эта лайка… Возможно, она ведёт меня куда-то?")
	await DialogueManager.dialogue_finished
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = false
		anim.play("walk")
	var tween := create_tween()
	tween.tween_property(laika, "global_position:x", laika.global_position.x + 400.0, 1.2)
	tween.parallel().tween_property(laika, "modulate:a", 0.0, 1.2)
	await tween.finished
	laika.visible = false
