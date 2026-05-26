class_name Interactable
extends Area2D

enum Type { DOOR, PICKABLE, EXAMINABLE, USABLE, TRIGGER, HIDEABLE }

@export var interaction_type: Type = Type.EXAMINABLE
@export var interaction_text: String = ""
@export var required_item: String = ""

func get_interaction_type() -> Type:
	return interaction_type

func interact(_player: CharacterBody2D) -> void:
	pass

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)
