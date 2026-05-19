extends Node2D

var fragments_placed: int = 0

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		var earring = get_node_or_null("EarringPickable")
		if earring:
			earring.queue_free()
		return

	# Pre-count fragments already in inventory (save/load resilience)
	for frag_id in ["mirror_fragment_1", "mirror_fragment_2", "mirror_fragment_3"]:
		if Inventory.has_item(frag_id):
			fragments_placed += 1

	if fragments_placed >= 3:
		_mirror_complete()
		return

	for frag_name in ["MirrorFragment1", "MirrorFragment2", "MirrorFragment3"]:
		var frag = get_node_or_null(frag_name)
		if frag:
			frag.picked_up.connect(func(_id): place_fragment())

	var earring = get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): on_earring_picked_up())

func place_fragment() -> void:
	fragments_placed += 1
	if fragments_placed >= 3:
		_mirror_complete()

func _mirror_complete() -> void:
	DialogueManager.show_text("", "Зеркало собрано. В отражении видна стена... но за ней — проход.")
	await DialogueManager.dialogue_finished
	var earring = get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func on_earring_picked_up() -> void:
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
	DialogueManager.start_dialogue("chapter2_balagan/flashback_earring")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
