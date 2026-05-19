extends Node2D

var correct_order: Array[String] = ["deer", "raven", "bear", "fish"]
var placed_stones: Array[String] = []
var puzzle_solved: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("shaman_drum"):
		var drum = get_node_or_null("DrumPickable")
		if drum:
			drum.queue_free()
		return

	for stone_data in [["StoneDeer", "deer"], ["StoneRaven", "raven"], ["StoneBear", "bear"], ["StoneFish", "fish"]]:
		var stone = get_node_or_null(stone_data[0])
		if stone:
			var symbol: String = stone_data[1]
			stone.examined.connect(func(): place_stone(symbol))

	var drum = get_node_or_null("DrumPickable")
	if drum:
		drum.picked_up.connect(func(_id): on_drum_picked_up())

func place_stone(symbol: String) -> void:
	placed_stones.append(symbol)
	if placed_stones.size() == correct_order.size():
		call_deferred("_check_solution")

func _check_solution() -> void:
	if placed_stones == correct_order:
		puzzle_solved = true
		var drum = get_node_or_null("DrumPickable")
		if drum:
			drum.visible = true
			drum.set_deferred("monitoring", true)
		DialogueManager.show_text("", "Камни засветились. За ними открылся тайник...")
	else:
		placed_stones.clear()
		DialogueManager.show_text("", "Ничего не произошло. Нужно попробовать другой порядок.")

func on_drum_picked_up() -> void:
	GameManager.collect_artifact("shaman_drum")
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
	DialogueManager.show_text("", "Видение: Айыына сидит у огня с бубном. Она поёт, но что-то идёт не так — тени на стенах начинают двигаться...")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
