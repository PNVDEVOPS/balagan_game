extends Node2D

func _ready() -> void:
	if GameManager.artifacts_collected.size() < 3:
		GameManager.current_room = "main_hall"
		get_tree().change_scene_to_file("res://scenes/rooms/room_main_hall.tscn")
		return
	_start_finale()

func _start_finale() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	var laika := get_tree().get_first_node_in_group("laika")
	var bg := $Background as ColorRect

	if fl:
		fl.scripted_off()

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Три артефакта на алтаре. Воздух вибрирует.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Силуэт Айыыны становится ярким, тёплым. Впервые — она улыбается.")
	await DialogueManager.dialogue_finished

	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.165, 0.102, 0.039), 2.0)
	await tween.finished

	DialogueManager.show_text("Айыына", "...Спасибо.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(2.0).timeout
	DialogueManager.show_text("", "Свет рассеивается. Айыына исчезает. Стены перестают дрожать.")
	await DialogueManager.dialogue_finished

	if fl:
		fl.scripted_on()

	DialogueManager.show_text("", "Дверь наружу открыта. Наконец-то.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	if laika:
		laika.follow_player()
	DialogueManager.show_text("", "Лайка идёт рядом. Впервые — не впереди, а рядом.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(2.0).timeout
	if laika:
		laika.velocity = Vector2.ZERO
		laika.state = laika.State.SIT_AT

	DialogueManager.show_text("", "На пороге оборачиваюсь. Она сидит. Не идёт за мной.")
	await DialogueManager.dialogue_finished

	DialogueManager.show_text("", "Тяну руку... Рука проходит сквозь.")
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
	DialogueManager.show_text("", "Тишина. Я один на пороге. Метель стихла.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(2.0).timeout
	_post_credits(bg)

func _post_credits(bg: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Машина заводится. Связь появилась.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "На заднем сиденье — костяной амулет. И рядом... маленький клок шерсти.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
