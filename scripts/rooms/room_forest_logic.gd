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

	var murder := get_node_or_null("ShamanAmulet")
	if not murder:
		murder = get_node_or_null("MurderSite")
	if murder:
		murder.examined.connect(_on_murder_site_examined)

	# Кыдаана note 2 — with fallback for old node name
	var kydaana2 := get_node_or_null("NoteKydaana2")
	if not kydaana2:
		kydaana2 = get_node_or_null("NoteAiyyna2")
	if kydaana2:
		kydaana2.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_2")
			GameManager.mark_note_found("note_kydaana_2")
		)

	# Father's last note (note_father_4)
	var father_last := get_node_or_null("NoteFatherLast")
	if father_last:
		father_last.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_father_4")
			GameManager.mark_note_found("note_father_4")
		)

	# Old NoteForestFather also maps to father notes
	var forest_father := get_node_or_null("NoteForestFather")
	if forest_father:
		forest_father.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_father_3")
			GameManager.mark_note_found("note_father_3")
		)

	var env2 := get_node_or_null("NoteEnv2")
	if env2:
		env2.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_env_2")
			GameManager.mark_note_found("note_env_2")
		)

func _on_murder_site_examined() -> void:
	DialogueManager.show_text("", "Птичьи кости, нанизанные на истлевшую нить. Давно. Кора дерева вросла в узел — значит, висит годами.\n\nТакое оставляют не как подношение. Как замок. Чтобы что-то не ушло с этого места.")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_appeared:
		return
	_laika_appeared = true

	if body.has_method("freeze"):
		body.freeze()

	var laika := get_node_or_null("Laika")
	if laika:
		laika.appear()

	DialogueManager.show_text("", "Наайда... Она здесь? Откуда?")
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
