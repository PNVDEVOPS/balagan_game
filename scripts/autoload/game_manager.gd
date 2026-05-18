extends Node

var current_room: String = "main_hall"
var artifacts_collected: Array[String] = []
var room_graph: Dictionary = {}
var transition_count: int = 0

func _ready() -> void:
	_load_room_graph()

func _load_room_graph() -> void:
	var file := FileAccess.open("res://data/room_graph.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		json.parse(file.get_as_text())
		room_graph = json.data
		file.close()

func get_door_target(room_id: String, door_id: String) -> String:
	if room_graph.has("rooms") and room_graph["rooms"].has(room_id):
		var doors: Dictionary = room_graph["rooms"][room_id].get("doors", {})
		return doors.get(door_id, "")
	return ""

func get_room_scene(room_id: String) -> String:
	if room_graph.has("rooms") and room_graph["rooms"].has(room_id):
		return room_graph["rooms"][room_id].get("scene", "")
	return ""

func change_room(door_id: String) -> void:
	var target_room := get_door_target(current_room, door_id)
	if target_room.is_empty():
		return
	var scene_path := get_room_scene(target_room)
	if scene_path.is_empty():
		return
	current_room = target_room
	transition_count += 1
	get_tree().change_scene_to_file(scene_path)
