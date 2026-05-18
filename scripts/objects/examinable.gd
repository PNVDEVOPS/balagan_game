extends Interactable

@export_multiline var examine_text: String = ""

func _ready() -> void:
	super._ready()
	interaction_type = Type.EXAMINABLE

func interact(player: CharacterBody2D) -> void:
	if not examine_text.is_empty():
		DialogueManager.show_text("", examine_text)
