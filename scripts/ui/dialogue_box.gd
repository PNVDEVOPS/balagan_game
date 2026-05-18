extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/VBoxContainer/TextLabel

var full_text: String = ""
var char_index: int = 0
var typewriter_speed: float = 0.03
var is_typing: bool = false

func _ready() -> void:
	panel.visible = false
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_line.connect(_on_dialogue_line)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_started() -> void:
	panel.visible = true

func _on_dialogue_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = not speaker.is_empty()
	full_text = text
	text_label.text = ""
	char_index = 0
	is_typing = true

func _on_dialogue_finished() -> void:
	panel.visible = false
	is_typing = false

func _process(delta: float) -> void:
	if not is_typing:
		return
	char_index += 1
	if char_index >= full_text.length():
		text_label.text = full_text
		is_typing = false
		return
	text_label.text = full_text.substr(0, char_index)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("advance_dialogue"):
		if is_typing:
			text_label.text = full_text
			is_typing = false
		else:
			DialogueManager.advance()
		get_viewport().set_input_as_handled()
