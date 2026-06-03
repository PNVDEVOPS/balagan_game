extends Interactable

signal examined()

@export_multiline var examine_text: String = ""

func _ready() -> void:
	super._ready()
	interaction_type = Type.EXAMINABLE

func interact(_player: CharacterBody2D) -> void:
	# Сначала emit — room-логика может запустить NotePopup или start_dialogue
	examined.emit()
	# show_text только если обработчик не открыл своё окно
	if not examine_text.is_empty() and not DialogueManager.is_active:
		DialogueManager.show_text("", examine_text)
