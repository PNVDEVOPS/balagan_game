extends Node

signal dialogue_started()
signal dialogue_line(speaker: String, text: String)
signal dialogue_finished()

var is_active: bool = false
var current_lines: Array = []
var current_index: int = 0

func start_dialogue(dialogue_id: String) -> void:
	var parts     := dialogue_id.split("/", false, 1)
	var file_name := parts[0]
	var key       := parts[1] if parts.size() > 1 else ""

	var lines := _load_lines(file_name, key)
	if lines.is_empty():
		dialogue_finished.emit()
		return

	# Записки с бумажным фоном идут в NotePopup
	var note_type := _note_type_for(key)
	if not note_type.is_empty():
		is_active = true
		NotePopup.open(lines, note_type)
		return

	# Обычный диалог
	current_lines = lines
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

# ---- helpers ----

func _load_lines(file_name: String, key: String) -> Array:
	var path := "res://data/dialogues/%s.json" % file_name
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("DialogueManager: file not found: %s" % path)
		return []
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	if key.is_empty():
		return json.data.get("lines", [])
	return json.data.get(key, [])

# Возвращает тип записки или пустую строку если это не бумажная записка
func _note_type_for(key: String) -> String:
	if key.begins_with("note_mother_"):  return "mother"
	if key.begins_with("note_father_"):  return "father"
	if key.begins_with("note_kydaana_"): return "kydaana"
	if key.begins_with("artifact_"):     return "kydaana"
	if key == "note_env_5":              return "kydaana"
	if key == "note_env_4":              return "father"
	if key == "note_env_hunting":        return "father"
	return ""
