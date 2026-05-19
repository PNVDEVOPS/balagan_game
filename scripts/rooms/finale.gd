extends Node2D

func _ready() -> void:
	ChapterManager.current_chapter = ChapterManager.Chapter.RELEASE
	await get_tree().process_frame
	if GameManager.ritual_result == "good":
		_start_good_ending()
	else:
		_start_bad_ending()

func _start_good_ending() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	var laika := get_tree().get_first_node_in_group("laika")
	var bg := $Background as ColorRect

	if fl:
		fl.scripted_off()

	await get_tree().create_timer(1.0).timeout

	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.165, 0.102, 0.039), 2.0)
	await tween.finished

	DialogueManager.start_dialogue("finale/good_part1")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout

	if laika:
		laika.follow_player()

	DialogueManager.start_dialogue("finale/good_part2")
	await DialogueManager.dialogue_finished

	if laika:
		var laika_tween := create_tween()
		laika.glow.energy = 1.0
		laika_tween.tween_property(laika, "modulate:a", 0.0, 3.0)
		laika_tween.parallel().tween_property(laika.glow, "energy", 2.0, 1.5)
		laika_tween.parallel().tween_property(laika.glow, "energy", 0.0, 1.5).set_delay(1.5)
		await get_tree().create_timer(1.5).timeout
		DialogueManager.show_text("", "Тихий скулёж. Она светится — так же, как Айыына.")
		await DialogueManager.dialogue_finished
		await laika_tween.finished

	await get_tree().create_timer(2.0).timeout
	_post_credits(bg)

func _start_bad_ending() -> void:
	var bg := $Background as ColorRect
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()

	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	DialogueManager.start_dialogue("finale/bad")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")

func _post_credits(bg: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Машина заводится. Связь появилась.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "На заднем сиденье — амулет. И рядом... маленький клок шерсти.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
