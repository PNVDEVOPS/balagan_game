extends Node2D

var note_read: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("bone_amulet"):
		var amulet = get_node_or_null("AmuletPickable")
		if amulet:
			amulet.queue_free()
		var note = get_node_or_null("NotePickable")
		if note:
			note.queue_free()
		return

	var note = get_node_or_null("NotePickable")
	if note:
		note.picked_up.connect(func(_id): on_note_picked_up())

	var shelf = get_node_or_null("Shelf")
	if shelf:
		shelf.examined.connect(on_shelf_examined)

	var amulet = get_node_or_null("AmuletPickable")
	if amulet:
		amulet.picked_up.connect(func(_id): on_amulet_picked_up())

func on_note_picked_up() -> void:
	note_read = true

func on_shelf_examined() -> void:
	if note_read or Inventory.has_item("note_shelf"):
		var amulet = get_node_or_null("AmuletPickable")
		if amulet:
			amulet.visible = true
			amulet.set_deferred("monitoring", true)
			DialogueManager.show_text("", "За иконой что-то спрятано...")

func on_amulet_picked_up() -> void:
	GameManager.collect_artifact("bone_amulet")
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
	DialogueManager.show_text("", "Видение: девушка входит в балаган, спасаясь от метели. Она улыбается — здесь тепло...")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
