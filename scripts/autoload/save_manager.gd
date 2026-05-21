extends Node

const SAVE_PATH := "user://save.json"

signal saved()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save() -> void:
	var data := {
		"current_chapter": int(ChapterManager.current_chapter),
		"current_room": GameManager.current_room,
		"artifacts_collected": Array(GameManager.artifacts_collected),
		"notes_found": Array(GameManager.notes_found),
		"inventory": Array(Inventory.items),
		"transition_count": GameManager.transition_count,
		"escape_attempts": GameManager.escape_attempts,
		"ritual_result": GameManager.ritual_result,
		"timestamp": Time.get_unix_time_from_system()
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
	saved.emit()

func autosave() -> void:
	save()

func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return false
	file.close()
	var data: Dictionary = json.data

	ChapterManager.current_chapter = data.get("current_chapter", 0) as ChapterManager.Chapter
	GameManager.current_room = str(data.get("current_room", "main_hall"))
	GameManager.transition_count = int(data.get("transition_count", 0))
	GameManager.escape_attempts = int(data.get("escape_attempts", 0))

	GameManager.artifacts_collected.clear()
	for item in data.get("artifacts_collected", []):
		GameManager.artifacts_collected.append(str(item))

	GameManager.notes_found.clear()
	for note_id in data.get("notes_found", []):
		GameManager.notes_found.append(str(note_id))

	Inventory.items.clear()
	for item in data.get("inventory", []):
		Inventory.items.append(str(item))

	GameManager.ritual_result = str(data.get("ritual_result", ""))
	GameManager.restore_from_save()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
