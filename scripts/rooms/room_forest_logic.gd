extends Node2D

var _laika_appeared: bool = false
var _chapter_started: bool = false

func _ready() -> void:
	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)
	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_appeared:
		return
	_laika_appeared = true
	var laika := get_node_or_null("Laika")
	if laika:
		laika.appear()
	DialogueManager.start_dialogue("forest_laika_appears")
	await DialogueManager.dialogue_finished
	if laika:
		laika.lead_to(Vector2(2300.0, 308.0))

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player") and not _chapter_started:
		_chapter_started = true
		ChapterManager.start_chapter(ChapterManager.Chapter.BALAGAN)
