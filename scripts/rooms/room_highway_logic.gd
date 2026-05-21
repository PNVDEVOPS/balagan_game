extends Node2D

var _narrative_shown: bool = false

func _ready() -> void:
	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)

	var narrative := get_node_or_null("NarrativeTrigger")
	if narrative:
		narrative.body_entered.connect(_on_narrative_trigger)

func _on_narrative_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _narrative_shown:
		return
	_narrative_shown = true
	DialogueManager.show_text("", "Тропа уходит в лес. Следы на снегу. Старые — но чьи?")

func _on_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_continue")
