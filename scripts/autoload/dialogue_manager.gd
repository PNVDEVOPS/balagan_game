extends Node

signal dialogue_started()
signal dialogue_line(speaker: String, text: String)
signal dialogue_finished()

var is_active: bool = false
var current_lines: Array = []
var current_index: int = 0

func start_dialogue(dialogue_id: String) -> void:
	var parts := dialogue_id.split("/", false, 1)
	var file_name := parts[0]
	var key := parts[1] if parts.size() > 1 else ""

	var path := "res://data/dialogues/%s.json" % file_name
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()

	if key.is_empty():
		current_lines = json.data.get("lines", [])
	else:
		current_lines = json.data.get(key, [])

	current_index = 0
	is_active = true
	dialogue_started.emit()
	_show_next_line()

func advance() -> void:
	if not is_active:
		return
	current_index += 1
	if current_index >= current_lines.size():
		is_active = false
		dialogue_finished.emit()
		return
	_show_next_line()

func _show_next_line() -> void:
	var line: Dictionary = current_lines[current_index]
	dialogue_line.emit(line.get("speaker", ""), line.get("text", ""))

func show_text(speaker: String, text: String) -> void:
	current_lines = [{"speaker": speaker, "text": text}]
	current_index = 0
	is_active = true
	dialogue_started.emit()
	_show_next_line()
