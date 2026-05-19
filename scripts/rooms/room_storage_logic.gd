extends Node2D

func _ready() -> void:
	var note4 := get_node_or_null("NoteAiyyna4")
	if note4:
		note4.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_4"))
