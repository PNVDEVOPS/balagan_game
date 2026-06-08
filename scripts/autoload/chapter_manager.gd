extends Node

enum Chapter { ROAD = 0, BALAGAN = 1, RELEASE = 2 }

signal chapter_started(chapter: Chapter)

var current_chapter: Chapter = Chapter.ROAD

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect

func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)

	_fade_rect = ColorRect.new()
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func start_chapter(chapter: Chapter) -> void:
	current_chapter = chapter
	var scene_path := _get_chapter_scene(chapter)
	var room_id := _get_chapter_room(chapter)

	# Уходим с улицы (ROAD) — гасим музыку начала.
	if chapter != Chapter.ROAD:
		AudioManager.stop_music(0.8)
	# В усадьбе — свой эмбиент (плавно перекрывает уличный). В финале — тишина.
	if chapter == Chapter.BALAGAN:
		var amb := "res://assets/audio/AmbientResident.mp3"
		if ResourceLoader.exists(amb):
			AudioManager.play_ambient(load(amb), 1.2)
	elif chapter == Chapter.RELEASE:
		AudioManager.stop_ambient(0.8)

	await _fade_out()

	GameManager.current_room = room_id
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager._place_player_at_door()
	SaveManager.autosave()
	await _fade_in()
	chapter_started.emit(chapter)

func _get_chapter_scene(chapter: Chapter) -> String:
	match chapter:
		Chapter.ROAD:
			var path := "res://scenes/rooms/room_highway.tscn"
			return path if ResourceLoader.exists(path) else "res://scenes/rooms/room_main_hall.tscn"
		Chapter.BALAGAN:
			return "res://scenes/rooms/room_entry.tscn"
		Chapter.RELEASE:
			return "res://scenes/rooms/room_finale.tscn"
	return "res://scenes/rooms/room_main_hall.tscn"

func _get_chapter_room(chapter: Chapter) -> String:
	match chapter:
		Chapter.ROAD: return "highway" if ResourceLoader.exists("res://scenes/rooms/room_highway.tscn") else "main_hall"
		Chapter.BALAGAN: return "entry"
		Chapter.RELEASE: return "finale"
	return "main_hall"

func _fade_out() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished

func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.8)
	await tween.finished
