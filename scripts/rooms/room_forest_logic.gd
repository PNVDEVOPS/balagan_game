extends Node2D

var _laika_appeared: bool = false
var _chapter_started: bool = false

func _ready() -> void:
	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)
	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	var murder := get_node_or_null("MurderSite")
	if murder:
		murder.examined.connect(_on_murder_site_examined)

	for note_data in [["NoteFatherLast", "notes/note_father_last"],
			["NoteAiyyna2", "notes/note_aiyyna_2"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_murder_site_examined() -> void:
	DialogueManager.show_text("", "Примятая трава. Старые следы борьбы. Снег здесь давно покраснел и стал чёрным.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Это место знакомо. Будто кто-то оставил здесь часть себя — навсегда.")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_appeared:
		return
	_laika_appeared = true

	if body.has_method("freeze"):
		body.freeze()

	var laika := get_node_or_null("Laika")
	if laika:
		laika.appear()

	DialogueManager.show_text("", "Лайка... Она здесь? Откуда?")
	await DialogueManager.dialogue_finished

	if laika and is_instance_valid(laika):
		laika.set_physics_process(false)
		var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
		if anim:
			anim.flip_h = false
			anim.play("walk")
		var tween := create_tween()
		tween.tween_property(laika, "global_position:x", laika.global_position.x + 520.0, 1.6)
		tween.parallel().tween_property(laika, "modulate:a", 0.0, 1.6)
		await tween.finished
		laika.visible = false

	if body.has_method("unfreeze"):
		body.unfreeze()

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player") and not _chapter_started:
		_chapter_started = true
		ChapterManager.start_chapter(ChapterManager.Chapter.BALAGAN)
