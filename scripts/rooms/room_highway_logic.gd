extends Node2D

var _car_examined: bool = false
var _narrative_shown: bool = false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)

	var narrative := get_node_or_null("NarrativeTrigger")
	if narrative:
		narrative.body_entered.connect(_on_narrative_trigger)

	var car := get_node_or_null("CarExamine")
	if car:
		car.examined.connect(_on_car_examined)

	_show_opening()

func _show_opening() -> void:
	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Приехали... Темнеет уже.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Надо из кабины фонарь забрать — а то в таком лесу лоб разобьёшь. Иначе я просто уйду в сугроб и не замечу")

func _on_car_examined() -> void:
	if _car_examined:
		DialogueManager.show_text("", "Надо идти вперёд — не то окоченею здесь.")
		return
	_car_examined = true
	DialogueManager.show_text("", "Так, попытка номер два. Может, всё-таки заведётся?")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "М-да, приехали. Аккумулятор окончательно сдох, даже аварийка не горит. Ладно, сидеть тут греться уже не получится")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Связи нет, глухо. Ладно, где тут фонарик был? В бардачке вроде...")
	await DialogueManager.dialogue_finished
	_give_flashlight()

func _give_flashlight() -> void:
	Inventory.add_item("flashlight")
	SubtitleManager.show_subtitle("[Вы взяли Фонарь]", SubtitleManager.Pos.TOP_CENTER)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.flashlight_ctrl.scripted_on()
	DialogueManager.show_text("", "Помню, мужики на заправке говорили, что тут деревня где-то в паре километров. Придётся прогуляться. Главное — фонарь не высадить, пока дойду")

func _on_narrative_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _narrative_shown:
		return
	_narrative_shown = true
	DialogueManager.show_text("", "Тропа уходит в лес. Следы на снегу. Старые — но чьи?")

func _on_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not Inventory.has_item("flashlight"):
		SubtitleManager.show_subtitle("Слишком темно. Хоть глаз выколи.", SubtitleManager.Pos.BOTTOM_CENTER)
		return
	GameManager.change_room("door_continue")
