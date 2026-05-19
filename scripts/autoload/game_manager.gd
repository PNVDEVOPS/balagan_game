extends Node

signal room_changed(room_id: String)
signal artifact_collected(artifact_id: String)

var current_room: String = "main_hall"
var artifacts_collected: Array[String] = []
var room_graph: Dictionary = {}
var transition_count: int = 0
var is_transitioning: bool = false
var spawn_door_id: String = ""

var _room_graph_original: Dictionary = {}
var _screen_fade: Node = null

func _ready() -> void:
	_load_room_graph()
	artifact_collected.connect(_on_artifact_collected)

func _load_room_graph() -> void:
	var file := FileAccess.open("res://data/room_graph.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		json.parse(file.get_as_text())
		room_graph = json.data
		_room_graph_original = json.data.duplicate(true)
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
	if is_transitioning:
		return
	var target_room := get_door_target(current_room, door_id)
	if target_room.is_empty():
		return
	var scene_path := get_room_scene(target_room)
	if scene_path.is_empty():
		return

	is_transitioning = true
	spawn_door_id = door_id

	_ensure_fade()
	await _screen_fade.fade_out(0.5)

	current_room = target_room
	transition_count += 1
	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	_place_player_at_door()
	_ensure_fade()
	await _screen_fade.fade_in(0.5)

	is_transitioning = false
	room_changed.emit(target_room)

func _place_player_at_door() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		return
	var spawn := get_tree().current_scene.get_node_or_null("SpawnPoint")
	if spawn:
		player.global_position = spawn.global_position

	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera:
		var room_right := get_tree().current_scene.get_node_or_null("RoomRight")
		var right_limit: int = int(room_right.global_position.x) if room_right else 640
		camera.limit_left = 0
		camera.limit_right = right_limit
		camera.limit_top = 0
		camera.limit_bottom = 360

func _ensure_fade() -> void:
	_screen_fade = get_tree().get_first_node_in_group("screen_fade")
	if not _screen_fade:
		var fade_scene := preload("res://scenes/ui/screen_fade.tscn")
		_screen_fade = fade_scene.instantiate()
		_screen_fade.add_to_group("screen_fade")
		get_tree().current_scene.add_child(_screen_fade)

func mutate_door(room_id: String, door_id: String, new_target: String) -> void:
	if room_graph["rooms"].has(room_id):
		room_graph["rooms"][room_id]["doors"][door_id] = new_target

func reset_room_graph() -> void:
	room_graph = _room_graph_original.duplicate(true)

func collect_artifact(artifact_id: String) -> void:
	if not artifacts_collected.has(artifact_id):
		artifacts_collected.append(artifact_id)
		artifact_collected.emit(artifact_id)

func _on_artifact_collected(artifact_id: String) -> void:
	match artifact_id:
		"bone_amulet":
			mutate_door("corridor", "door_right", "main_hall")
		"shaman_drum":
			mutate_door("entrance", "door_inside", "corridor")
			mutate_door("bedroom", "door_back", "storage")
		"earring":
			reset_room_graph()
			mutate_door("entrance", "door_outside", "finale")
			room_graph["rooms"]["finale"] = {
				"scene": "res://scenes/rooms/room_finale.tscn",
				"doors": {}
			}

func teleport_to_random_room() -> void:
	var room_ids: Array = room_graph["rooms"].keys()
	room_ids.erase(current_room)
	if room_ids.is_empty():
		return
	var random_room: String = room_ids[randi() % room_ids.size()]
	var scene_path := get_room_scene(random_room)
	if scene_path.is_empty():
		return

	is_transitioning = true
	_ensure_fade()
	await _screen_fade.fade_out(0.3)
	current_room = random_room
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_fade()
	await _screen_fade.fade_in(0.8)
	is_transitioning = false
