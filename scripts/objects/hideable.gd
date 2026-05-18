extends Interactable

var player_ref: CharacterBody2D = null

func _ready() -> void:
	super._ready()
	interaction_type = Type.HIDEABLE

func get_interaction_type() -> Type:
	return Type.HIDEABLE

func interact(_player: CharacterBody2D) -> void:
	pass

func hide_player(player: CharacterBody2D) -> void:
	player_ref = player
	player.is_hiding = true
	player.visible = false
	player.position = global_position

func _unhandled_input(event: InputEvent) -> void:
	if player_ref and player_ref.is_hiding:
		if event.is_action_pressed("hide") or event.is_action_pressed("interact"):
			unhide()

func unhide() -> void:
	if player_ref:
		player_ref.is_hiding = false
		player_ref.visible = true
		player_ref = null
