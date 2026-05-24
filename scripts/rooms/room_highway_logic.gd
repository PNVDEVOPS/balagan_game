extends Node2D

var _narrative_shown: bool = false

func _ready() -> void:
	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)

	var narrative := get_node_or_null("NarrativeTrigger")
	if narrative:
		narrative.body_entered.connect(_on_narrative_trigger)

	var phone := get_node_or_null("PhoneExamine")
	if phone:
		phone.examined.connect(_on_phone_examined)

	var hood := get_node_or_null("HoodExamine")
	if hood:
		hood.examined.connect(_on_hood_examined)

func _on_phone_examined() -> void:
	DialogueManager.show_text("", "Три деления сигнала — и вдруг ноль.\nМетель глушит всё. Никого не дозвониться.\n\nПоследнее сообщение — четыре часа назад.")

func _on_hood_examined() -> void:
	DialogueManager.show_text("", "Стрелки мёртвые. Ключ поворачивается — двигатель молчит.\n\nБатарея. Или мороз. Машину не завести.")

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
