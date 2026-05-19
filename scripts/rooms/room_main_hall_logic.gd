extends Node2D

static var _wake_up_shown: bool = false

func _ready() -> void:
	if not _wake_up_shown and ChapterManager.current_chapter == ChapterManager.Chapter.BALAGAN and GameManager.artifacts_collected.is_empty():
		_wake_up_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.start_dialogue("chapter2_balagan/wake_up")
