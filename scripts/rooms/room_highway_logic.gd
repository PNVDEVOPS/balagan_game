extends Node2D

const AMBIENT_OUT  := "res://assets/audio/AmbientOut.mp3"
const START_MELODY := "res://assets/audio/Start Melody.mp3"

var _car_examined: bool = false
var _narrative_shown: bool = false

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	# Уличный эмбиент (Highway/Forest)
	if ResourceLoader.exists(AMBIENT_OUT):
		AudioManager.play_ambient(load(AMBIENT_OUT))

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
	DialogueManager.show_text("", "Приехали... Двигатель заглох.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Темно. Нужен фонарик.")

func _on_car_examined() -> void:
	if _car_examined:
		DialogueManager.show_text("", "Холодно. Надо найти помощь.")
		return
	_car_examined = true
	DialogueManager.show_text("", "Может, всё-таки заведётся?")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Аккумулятор окончательно сдох, даже аварийка не горит.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Связи нет, глухо. Где тут фонарик был? Кажется в бардачке")
	await DialogueManager.dialogue_finished
	_give_flashlight()

func _give_flashlight() -> void:
	Inventory.add_item("flashlight")
	# Музыка начала игры — стартует с подбором фонарика
	if ResourceLoader.exists(START_MELODY):
		AudioManager.play_music(load(START_MELODY))
	var flashlight_tex: Texture2D = null
	var icon := "res://assets/sprites/items/flashlight_hand.png"
	if ResourceLoader.exists(icon):
		flashlight_tex = load(icon)
	ItemPopup.show_item("Фонарик", "Аккумулятор заряжен — пока выручает.", flashlight_tex)
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.flashlight_ctrl.refresh_kind()   # инвентарь изменился — пересчитать режим (был DARK)
		player.flashlight_ctrl.scripted_on()
		if player.has_method("refresh_appearance"):
			player.refresh_appearance()          # пересчитать спрайт тела (без предмета в руке)
	DialogueManager.show_text("", "Вроде работает. Главное — фонарик не высадить")

func _on_narrative_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _narrative_shown:
		return
	_narrative_shown = true
	DialogueManager.show_text("", "Тропа уходит в лес. Свежие следы на снегу.")

func _on_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not Inventory.has_item("flashlight"):
		SubtitleManager.show_subtitle("Слишком темно. Хоть глаз выколи.", SubtitleManager.Pos.BOTTOM_CENTER)
		return
	GameManager.change_room("door_continue")
