extends Node2D

var _naayda_triggered: bool = false

func _ready() -> void:
	var room_id: String = GameManager.current_room

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	await get_tree().process_frame
	_maybe_show_subtitle(room_id)

	if room_id == "corridor":
		var laika_trigger := get_node_or_null("LaikaTrigger")
		if laika_trigger:
			laika_trigger.body_entered.connect(_on_laika_trigger)

func _maybe_show_subtitle(room_id: String) -> void:
	var has_amulet: bool = GameManager.artifacts_collected.has("amulet")
	var has_doll: bool = GameManager.artifacts_collected.has("doll")
	match room_id:
		"corridor":
			if has_amulet and not has_doll:
				SubtitleManager.show_subtitle("Зачем ты это делаешь?", SubtitleManager.Pos.MID_LEFT)
		"corridor2":
			if has_doll:
				SubtitleManager.show_subtitle("Это не поможет.", SubtitleManager.Pos.MID_RIGHT)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _naayda_triggered:
		return
	_naayda_triggered = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	await get_tree().create_timer(1.0).timeout
	var tw := create_tween()
	tw.tween_property(laika, "global_position:x", laika.global_position.x + 400.0, 1.2)
	tw.parallel().tween_property(laika, "modulate:a", 0.0, 1.2)
	await tw.finished
	laika.visible = false
