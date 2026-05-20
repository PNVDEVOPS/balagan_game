extends Node2D

# Position of DoorDown in this room (matches scene placement)
const DOOR_DOWN_POS := Vector2(1200.0, 320.0)

var _hint_shown: bool = false

func _ready() -> void:
	await get_tree().process_frame
	var laika := get_node_or_null("Laika")
	if laika:
		laika.appear()
		# Walk to the locked door and sit
		laika.lead_to(Vector2(DOOR_DOWN_POS.x - 50.0, DOOR_DOWN_POS.y - 20.0))

	_setup_door_trigger()

func _setup_door_trigger() -> void:
	var area := Area2D.new()
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 90.0
	shape_node.shape = circle
	area.position = DOOR_DOWN_POS
	area.collision_layer = 0
	area.collision_mask = 1
	area.add_child(shape_node)
	add_child(area)
	area.body_entered.connect(_on_player_near_laika_door)

func _on_player_near_laika_door(body: Node2D) -> void:
	if _hint_shown or not body.is_in_group("player"):
		return
	var laika := get_node_or_null("Laika")
	if laika and laika.state == laika.State.SIT_AT:
		_hint_shown = true
		DialogueManager.show_text("", "Лайка сидит у этой двери... Может быть, она хочет, чтобы я именно здесь её и открыл.")
