extends Node2D

var fragments_placed: int = 0

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		var earring = get_node_or_null("EarringPickable")
		if earring:
			earring.queue_free()

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
	DialogueManager.show_text("", "Видение: Айыына кричит. Тени обступают её. Она пытается бежать, но двери нет. Стены смыкаются...")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Видение: тишина. Серьга падает на пол. Девушки больше нет.")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
