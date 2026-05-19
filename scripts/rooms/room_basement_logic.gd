extends Node2D

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		for node_name in ["KeyPickable", "ChestEarring", "EarringPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	var riddle := get_node_or_null("RiddleMirror")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_mirror"))

	var mirror := get_node_or_null("OldMirror")
	if mirror:
		mirror.examined.connect(_on_mirror_examined)

	var chest := get_node_or_null("ChestEarring")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): _on_earring_picked_up())

	var note5 := get_node_or_null("NoteAiyyna5")
	if note5:
		note5.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_5"))

func _on_mirror_examined() -> void:
	var key := get_node_or_null("KeyPickable")
	if key and not key.visible:
		DialogueManager.show_text("", "Старое зеркало. В отражении — тот же подвал, но немного другой. За зеркалом что-то блестит.")
		await DialogueManager.dialogue_finished
		key.visible = true
		key.set_deferred("monitoring", true)
	else:
		DialogueManager.show_text("", "В отражении видишь себя. Позади — тень, которой нет.")

func _on_chest_used() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_trigger_flashback()

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_earring")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
