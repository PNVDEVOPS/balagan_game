extends Area2D

var interaction_type: int = Interactable.Type.EXAMINABLE
var interaction_text: String = "Погладить"

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)

func get_interaction_type() -> int:
	return interaction_type

func interact(_player: CharacterBody2D) -> void:
	var laika := get_parent()
	if laika and laika.has_method("bark"):
		laika.bark()
