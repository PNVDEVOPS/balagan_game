extends Node2D

func _ready() -> void:
	var room_id: String = GameManager.current_room

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	if room_id == "entry2":
		_setup_naayda()

	if room_id == "entry" and GameManager.escape_attempts == 0 and GameManager.transition_count <= 2:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)

	var clothes := get_node_or_null("ClothesExaminable")
	if clothes:
		clothes.examined.connect(func():
			SubtitleManager.show_subtitle("Не трогай.", SubtitleManager.Pos.MID_LEFT)
		)

func _on_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	match GameManager.escape_attempts:
		2:
			SubtitleManager.show_subtitle("Ты не выйдешь.", SubtitleManager.Pos.BOTTOM_RIGHT)
		3:
			SubtitleManager.show_subtitle("Отсюда нет выхода.", SubtitleManager.Pos.TOP_CENTER)
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _setup_naayda() -> void:
	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	await get_tree().create_timer(1.2).timeout
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = false
	var tw := create_tween()
	tw.tween_property(laika, "global_position:x", laika.global_position.x + 300.0, 1.0)
	tw.parallel().tween_property(laika, "modulate:a", 0.0, 1.0)
	await tw.finished
	laika.visible = false
