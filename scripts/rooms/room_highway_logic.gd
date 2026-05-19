extends Node2D

var _intro_shown: bool = false

func _ready() -> void:
	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)
	if not _intro_shown:
		_intro_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.start_dialogue("highway_arrival")

	for note_data in [["NoteFather1", "notes/note_father_1"], ["NoteFather2", "notes/note_father_2"],
			["NoteFather3", "notes/note_father_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_continue")
