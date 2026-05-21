extends Node2D

var _mirror_minigame_active: bool = false
var _mirror_solved: bool = false
var _naayda_greeted: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		for node_name: String in ["KeyPickable", "ChestEarring", "EarringPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	await get_tree().process_frame
	_setup_naayda()

	var riddle := get_node_or_null("RiddleMirror")
	if riddle:
		riddle.examined.connect(func():
			DialogueManager.start_dialogue("notes/riddle_mirror")
			GameManager.mark_note_found("riddle_mirror")
		)

	var mirror := get_node_or_null("OldMirror")
	if mirror:
		mirror.examined.connect(_on_mirror_examined)

	var drawings := get_node_or_null("DrawingsExaminable")
	if drawings:
		drawings.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Я нарисовала это когда думала что всё будет хорошо.",
				SubtitleManager.Pos.TOP_LEFT
			)
		)

	var clothes := get_node_or_null("ClothesExaminable")
	if clothes:
		clothes.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Я её больше не надену.",
				SubtitleManager.Pos.MID_RIGHT
			)
		)

	var bed := get_node_or_null("BedExaminable")
	if bed:
		bed.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Здесь я видела сны. Хорошие — в начале.",
				SubtitleManager.Pos.TOP_CENTER
			)
		)

	var note5 := get_node_or_null("NoteKydaana5")
	if note5:
		note5.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_5")
			GameManager.mark_note_found("note_kydaana_5")
		)

	var note4 := get_node_or_null("NoteKydaana4")
	if note4:
		note4.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_4")
			GameManager.mark_note_found("note_kydaana_4")
		)

	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): _on_earring_picked_up())

	var chest := get_node_or_null("ChestEarring")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var floorboard := get_node_or_null("SecretFloorboard")
	if floorboard:
		floorboard.examined.connect(_on_floorboard_examined)

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	SubtitleManager.show_subtitle_pair(
		"Не трогай мои вещи.",
		SubtitleManager.Pos.TOP_RIGHT,
		3.0,
		"...пожалуйста.",
		SubtitleManager.Pos.BOTTOM_LEFT
	)

func _setup_naayda() -> void:
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.sit_at(laika.global_position)
	laika.appear()
	var approach_zone := get_node_or_null("LaikaTrigger")
	if approach_zone:
		approach_zone.body_entered.connect(_on_approach_naayda)

func _on_approach_naayda(body: Node2D) -> void:
	if not body.is_in_group("player") or _naayda_greeted:
		return
	_naayda_greeted = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = true
	await get_tree().create_timer(1.5).timeout
	var tw := create_tween()
	tw.tween_property(laika, "modulate:a", 0.0, 1.5)
	await tw.finished
	laika.visible = false

func _on_mirror_examined() -> void:
	if _mirror_minigame_active:
		return
	if _mirror_solved:
		DialogueManager.show_text("", "Зеркало собрано. Ты помнишь — третья доска от окна, где сучок звездой.")
		return
	SubtitleManager.show_subtitle(
		"Оно разбилось в ту ночь. Я не смотрелась с тех пор.",
		SubtitleManager.Pos.MID_LEFT
	)
	DialogueManager.start_dialogue("notes/riddle_mirror")
	await DialogueManager.dialogue_finished
	_launch_mirror_minigame()

func _launch_mirror_minigame() -> void:
	_mirror_minigame_active = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()
	var scene := preload("res://scenes/minigames/minigame_mirror.tscn")
	var mg: MinigameMirror = scene.instantiate()
	get_tree().current_scene.add_child(mg)
	mg.minigame_completed.connect(_on_mirror_solved_signal)
	mg.minigame_cancelled.connect(_on_mirror_cancelled)

func _on_mirror_solved_signal(_id: String) -> void:
	_mirror_minigame_active = false
	_mirror_solved = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
	DialogueManager.show_text("", "Зеркало собралось. В нём — отражение комнаты. Там, где сучок в доске похож на звезду, что-то спрятано.")
	await DialogueManager.dialogue_finished
	var floorboard := get_node_or_null("SecretFloorboard")
	if floorboard:
		floorboard.visible = true
		floorboard.set_deferred("monitoring", true)

func _on_mirror_cancelled() -> void:
	_mirror_minigame_active = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func _on_floorboard_examined() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_chest_used() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_trigger_flashback()

func _on_forward_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not GameManager.artifacts_collected.has("earring"):
		SubtitleManager.show_subtitle("Здесь ещё что-то есть.", SubtitleManager.Pos.MID_LEFT)
		return
	GameManager.change_room("door_forward")

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := get_node_or_null("Background") as ColorRect
	var original_color := bg.color if bg else Color.BLACK
	if bg:
		var tw := create_tween()
		tw.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
		await tw.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_earring")
	await DialogueManager.dialogue_finished
	if bg:
		var tw := create_tween()
		tw.tween_property(bg, "color", original_color, 1.0)
		await tw.finished
	if fl:
		fl.scripted_on()
