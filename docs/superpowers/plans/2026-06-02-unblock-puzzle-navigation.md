# Unblock Puzzle, Back Navigation, Chapter Fade — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a sliding-block unblock puzzle to the main hall fireplace, back navigation through corridors, loop reactions in key rooms, remove chapter title cards, and fix the first Kydaana subtitle position.

**Architecture:** Seven independent tasks in dependency order. MinigameUnblock is a new CanvasLayer (same pattern as MinigameCradle). Back navigation and loop reactions are added programmatically in room `_ready()` functions — no .tscn edits required. room_graph.json gets `door_back` edges for corridors and `door_exit` self-loops for closet/main_hall/storage.

**Tech Stack:** Godot 4.3+, GDScript 2.0, room_graph.json

---

### Task 1: Fix first Kydaana subtitle position

**Files:**
- Modify: `scripts/rooms/room_corridor_logic.gd:23`

- [ ] **Step 1: Change position from TOP_LEFT to TOP_CENTER**

In `scripts/rooms/room_corridor_logic.gd`, line 23, change:
```gdscript
SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)
```
to:
```gdscript
SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_CENTER)
```

- [ ] **Step 2: Commit**
```
git add scripts/rooms/room_corridor_logic.gd
git commit -m "fix: first Kydaana subtitle TOP_LEFT -> TOP_CENTER"
```

---

### Task 2: Remove chapter title cards

**Files:**
- Modify: `scripts/autoload/chapter_manager.gd`

- [ ] **Step 1: Replace the entire file**

Replace `scripts/autoload/chapter_manager.gd` with:
```gdscript
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
```

- [ ] **Step 2: Commit**
```
git add scripts/autoload/chapter_manager.gd
git commit -m "feat: remove chapter title cards, keep fade transitions"
```

---

### Task 3: Add door_back and door_exit to room_graph.json

**Files:**
- Modify: `data/room_graph.json`

- [ ] **Step 1: Replace the entire file**

Replace `data/room_graph.json` with:
```json
{
  "rooms": {
    "highway": {
      "scene": "res://scenes/rooms/room_highway.tscn",
      "doors": { "door_continue": "forest" }
    },
    "forest": {
      "scene": "res://scenes/rooms/room_forest.tscn",
      "doors": {}
    },
    "entry": {
      "scene": "res://scenes/rooms/room_entry.tscn",
      "doors": { "door_forward": "entry_c1", "door_exit": "entry" }
    },
    "entry_c1": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "entry_c2", "door_back": "entry" }
    },
    "entry_c2": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "closet", "door_back": "entry_c1" }
    },
    "entry_c3": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "entry_c4", "door_back": "closet" }
    },
    "entry_c4": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "main_hall", "door_back": "entry_c3" }
    },
    "closet": {
      "scene": "res://scenes/rooms/room_closet.tscn",
      "doors": { "door_forward": "entry_c3", "door_exit": "closet" }
    },
    "entry2": {
      "scene": "res://scenes/rooms/room_entry.tscn",
      "doors": { "door_forward": "main_hall", "door_exit": "main_hall" }
    },
    "main_hall": {
      "scene": "res://scenes/rooms/room_main_hall.tscn",
      "doors": { "door_right": "corridor", "door_exit": "main_hall" }
    },
    "corridor": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "dining", "door_back": "main_hall" }
    },
    "dining": {
      "scene": "res://scenes/rooms/room_dining.tscn",
      "doors": { "door_forward": "bedroom" }
    },
    "bedroom": {
      "scene": "res://scenes/rooms/room_bedroom.tscn",
      "doors": { "door_forward": "corridor2" }
    },
    "corridor2": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "corridor3", "door_back": "bedroom" }
    },
    "corridor3": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "storage", "door_back": "corridor2" }
    },
    "storage": {
      "scene": "res://scenes/rooms/room_storage.tscn",
      "doors": { "door_forward": "kydaana_room", "door_exit": "storage" }
    },
    "kydaana_room": {
      "scene": "res://scenes/rooms/room_kydaana.tscn",
      "doors": { "door_forward": "entry3" }
    },
    "entry3": {
      "scene": "res://scenes/rooms/room_entry.tscn",
      "doors": { "door_forward": "entry4", "door_exit": "main_hall" }
    },
    "entry4": {
      "scene": "res://scenes/rooms/room_entry.tscn",
      "doors": { "door_forward": "main_hall", "door_exit": "main_hall" }
    }
  }
}
```

- [ ] **Step 2: Commit**
```
git add data/room_graph.json
git commit -m "feat: add door_back for corridors, door_exit self-loops for closet/main_hall/storage"
```

---

### Task 4: Back navigation in corridors

**Files:**
- Modify: `scripts/rooms/room_corridor_logic.gd`

BackZone is added programmatically at x=-20 (left wall area), full room height. When player enters it, `change_room("door_back")` is called. Player spawning from the right side is handled by checking `GameManager.spawn_door_id == "door_back"` and repositioning x to 1450.

Static var `_visit_counts` persists across room reloads to track how many times each corridor was visited.

- [ ] **Step 1: Replace the entire file**

Replace `scripts/rooms/room_corridor_logic.gd` with:
```gdscript
extends Node2D

var _window_examined: bool = false
var _laika_triggered: bool = false
static var _visit_counts: Dictionary = {}

func _ready() -> void:
	var room_id: String = GameManager.current_room

	if not _visit_counts.has(room_id):
		_visit_counts[room_id] = 0
	_visit_counts[room_id] += 1

	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1600
		if GameManager.spawn_door_id == "door_back":
			player.global_position.x = 1450.0

	_add_back_zone()

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	if room_id == "entry_c3":
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_CENTER)

	var window := get_node_or_null("WindowExamine")
	if window:
		_setup_window(window, room_id)

	var note := get_node_or_null("NoteCorr1")
	if note:
		_setup_note(note, room_id)

	if room_id == "entry_c4":
		var laika_trigger := get_node_or_null("LaikaTrigger")
		if laika_trigger:
			laika_trigger.body_entered.connect(_on_laika_trigger)

	_show_revisit_reaction(room_id)

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_back")

func _show_revisit_reaction(room_id: String) -> void:
	var count: int = _visit_counts.get(room_id, 1)
	if count == 2:
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.show_text("", "Опять этот коридор.")
	elif count >= 3:
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.show_text("", "Снова и снова. Стены одинаковые.")

func _setup_window(window: Node, room_id: String) -> void:
	match room_id:
		"entry_c1":
			window.examine_text = "Двор занесло по пояс. Забор — едва угадывается. Где-то там загон, дровяник, тропинка к реке. Сейчас всё одно — белое."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Смотрю и жду, что появится хоть кто-то. Но снег ровный — ни следа, ни огня."
			)
		"entry_c2":
			window.examine_text = "Метель стихает. Небо чуть светлее у горизонта — не рассвет, просто луна за облаком."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Деревья стоят неподвижно. Как будто слушают."
			)
		"entry_c3":
			window.examine_text = "Тьма за стеклом такая плотная, что смотришь в неё — и кажется, что она смотрит обратно."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "Там что-то есть. Или было. Я отошёл от окна."
			)
		"entry_c4":
			window.examine_text = "Дорога почти исчезла под снегом. Следы мои уже замело — будто я не приходил. Обратного пути нет."
		_:
			window.examine_text = "Темно за окном."

func _setup_note(note: Node, room_id: String) -> void:
	var note_key := ""
	match room_id:
		"entry_c1": note_key = "note_env_2"
		"corridor2": note_key = "note_father_4"
		"entry_c4":
			note_key = "note_haryshal"
			note.interaction_text = "Осмотреть записку на тумбе"
	if note_key.is_empty():
		note.queue_free()
		return
	note.examined.connect(func():
		DialogueManager.start_dialogue("notes/" + note_key)
		GameManager.mark_note_found(note_key)
	)

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_triggered:
		return
	_laika_triggered = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	DialogueManager.show_text("", "Опять эта лайка… Возможно, она ведёт меня куда-то?")
	await DialogueManager.dialogue_finished
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = false
		anim.play("walk")
	var tween := create_tween()
	tween.tween_property(laika, "global_position:x", laika.global_position.x + 400.0, 1.2)
	tween.parallel().tween_property(laika, "modulate:a", 0.0, 1.2)
	await tween.finished
	laika.visible = false
```

- [ ] **Step 2: Commit**
```
git add scripts/rooms/room_corridor_logic.gd
git commit -m "feat: corridor back navigation and revisit reactions"
```

---

### Task 5: Loop room reactions (entry, closet, storage)

**Files:**
- Modify: `scripts/rooms/room_entry_logic.gd`
- Modify: `scripts/rooms/room_closet_logic.gd`
- Modify: `scripts/rooms/room_storage_logic.gd`

Each gets a BackZone at x=-20 that fires `change_room("door_exit")` (which loops back per room_graph). The player sees a dialogue reaction before the fade.

Note: room_main_hall_logic.gd gets BackZone in Task 7 as part of its full rewrite.

- [ ] **Step 1: Replace room_entry_logic.gd**

Replace `scripts/rooms/room_entry_logic.gd` with:
```gdscript
extends Node2D

var _back_trigger_count: int = 0

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1280

	var exit_door := get_node_or_null("ExitDoorZone")
	if exit_door:
		exit_door.body_entered.connect(_on_exit_door)

	var forward := get_node_or_null("ForwardZone")
	if forward:
		forward.body_entered.connect(_on_forward_zone)

	var note := get_node_or_null("NoteEntry1")
	if note:
		note.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_env_hunting")
			GameManager.mark_note_found("note_env_hunting")
		)

	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)

	_add_back_zone()

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 2: Replace room_closet_logic.gd**

Replace `scripts/rooms/room_closet_logic.gd` with:
```gdscript
extends Node2D

var _back_trigger_count: int = 0

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 640

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var shelves := get_node_or_null("ShelvesExamine")
	if shelves:
		shelves.examined.connect(func():
			DialogueManager.show_text("", "Банки с припасами. Большинство пустые. Одна треснула — содержимое давно высохло.\n\nНа самой верхней — охотничий нож в потёртых ножнах. Чистый.")
		)

	var kapkans := get_node_or_null("KapkansExaminable")
	if kapkans:
		kapkans.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Отец их больше не поднимет.",
				SubtitleManager.Pos.BOTTOM_CENTER
			)
			GameManager.mark_note_found("note_father_1")
			DialogueManager.start_dialogue("notes/note_father_1")
		)

	var chest := get_node_or_null("ChestExaminable")
	if chest:
		chest.examined.connect(func():
			GameManager.mark_note_found("note_father_2")
			DialogueManager.start_dialogue("notes/note_father_2")
		)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Ты не должен быть здесь.",
		SubtitleManager.Pos.MID_LEFT
	)

	_add_back_zone()

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 3: Replace room_storage_logic.gd**

Replace `scripts/rooms/room_storage_logic.gd` with:
```gdscript
extends Node2D

var _back_trigger_count: int = 0

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var bags := get_node_or_null("BagsExaminable")
	if bags:
		bags.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Отец считал их каждую ночь. Думал — я не вижу.",
				SubtitleManager.Pos.BOTTOM_LEFT
			)
		)

	var note_env := get_node_or_null("NoteEnv3")
	if note_env:
		note_env.examined.connect(func():
			GameManager.mark_note_found("note_env_4")
			DialogueManager.start_dialogue("notes/note_env_4")
		)

	for note_data: Array in [
			["NoteKydaana4", "notes/note_kydaana_4", "note_kydaana_4"],
			["NoteKydaana3", "notes/note_kydaana_3", "note_kydaana_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		var note_id: String = note_data[2]
		if note:
			note.examined.connect(func():
				GameManager.mark_note_found(note_id)
				DialogueManager.start_dialogue(key)
			)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Запасов хватило бы до весны. Но весны не было.",
		SubtitleManager.Pos.TOP_CENTER
	)

	_add_back_zone()

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 4: Commit**
```
git add scripts/rooms/room_entry_logic.gd scripts/rooms/room_closet_logic.gd scripts/rooms/room_storage_logic.gd
git commit -m "feat: BackZone loop reactions for entry, closet, storage"
```

---

### Task 6: Create MinigameUnblock

**Files:**
- Create: `scripts/minigames/minigame_unblock.gd`

Puzzle layout (6×6 grid, exit right at row 2):
```
Row 0: . . C C C E
Row 1: . . A B . E
Row 2: K K A B D .   ← Exit →
Row 3: . . . . D .
Row 4: F F . . . .
Row 5: . . . . . .
```
Solution (4 moves): move A down → move B down → move D down → slide K right to exit.

Controls: click a block to select it (highlighted), then click elsewhere in same row/column to slide it there. Arrow keys also move the selected block one step.

- [ ] **Step 1: Create the file**

Create `scripts/minigames/minigame_unblock.gd`:
```gdscript
class_name MinigameUnblock
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const GRID_COLS := 6
const GRID_ROWS := 6
const EXIT_ROW := 2
const CELL := 80

# [row, col, is_horizontal, length, is_amulet]
const LAYOUT: Array = [
	[2, 0, true,  2, true],
	[1, 2, false, 2, false],
	[1, 3, false, 2, false],
	[0, 2, true,  3, false],
	[2, 4, false, 2, false],
	[0, 5, false, 2, false],
	[4, 0, true,  2, false],
]

const COLOR_WOOD   := Color(0.45, 0.28, 0.12)
const COLOR_AMULET := Color(0.85, 0.65, 0.10)
const COLOR_SELECT := Color(1.0, 1.0, 1.0, 0.35)
const COLOR_BG     := Color(0.10, 0.07, 0.04)
const COLOR_GRID   := Color(0.06, 0.04, 0.02)
const COLOR_EXIT   := Color(0.85, 0.65, 0.10, 0.25)

var _blocks: Array = []
var _selected: int = -1
var _can_interact: bool = true
var _grid_ctrl: Control

func _ready() -> void:
	layer = 10
	for entry in LAYOUT:
		_blocks.append({r = entry[0], c = entry[1], horiz = entry[2], len = entry[3], amulet = entry[4]})
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.88)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)

	var title := Label.new()
	title.text = "Разгреби дрова — освободи путь"
	title.add_theme_font_size_override("font_size", 18)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200.0, 50.0)
	title.size = Vector2(400.0, 36.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var grid_size := float(CELL * GRID_COLS)
	_grid_ctrl = Control.new()
	_grid_ctrl.name = "GridCtrl"
	_grid_ctrl.set_anchors_preset(Control.PRESET_CENTER)
	_grid_ctrl.position = Vector2(-grid_size / 2.0, -grid_size / 2.0)
	_grid_ctrl.size = Vector2(grid_size, grid_size)
	_grid_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	_grid_ctrl.draw.connect(_on_grid_draw)
	_grid_ctrl.gui_input.connect(_on_grid_input)
	add_child(_grid_ctrl)

	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Закрыть [ESC]"
	close_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close_btn.position = Vector2(-180.0, -70.0)
	close_btn.size = Vector2(160.0, 40.0)
	close_btn.pressed.connect(_on_close)
	add_child(close_btn)

func _on_grid_draw() -> void:
	_grid_ctrl.draw_rect(Rect2(Vector2.ZERO, _grid_ctrl.size), COLOR_BG)
	for i in range(GRID_COLS + 1):
		var x := float(i * CELL)
		_grid_ctrl.draw_line(Vector2(x, 0), Vector2(x, _grid_ctrl.size.y), COLOR_GRID, 1.0)
	for i in range(GRID_ROWS + 1):
		var y := float(i * CELL)
		_grid_ctrl.draw_line(Vector2(0, y), Vector2(_grid_ctrl.size.x, y), COLOR_GRID, 1.0)
	var ey := EXIT_ROW * CELL
	_grid_ctrl.draw_rect(Rect2(Vector2(_grid_ctrl.size.x - 4, ey + 6), Vector2(6, CELL - 12)), COLOR_EXIT)
	for i in range(_blocks.size()):
		var b: Dictionary = _blocks[i]
		var rect := _block_rect(b)
		var col := COLOR_AMULET if b.amulet else COLOR_WOOD
		_grid_ctrl.draw_rect(rect.grow(-4), col)
		if i == _selected:
			_grid_ctrl.draw_rect(rect.grow(-4), COLOR_SELECT)
		_grid_ctrl.draw_rect(rect.grow(-4), Color(0, 0, 0, 0.4), false, 2.0)

func _block_rect(b: Dictionary) -> Rect2:
	var w := float(CELL * b.len) if b.horiz else float(CELL)
	var h := float(CELL) if b.horiz else float(CELL * b.len)
	return Rect2(float(b.c * CELL), float(b.r * CELL), w, h)

func _on_grid_input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var col := int(event.position.x / CELL)
	var row := int(event.position.y / CELL)
	col = clampi(col, 0, GRID_COLS - 1)
	row = clampi(row, 0, GRID_ROWS - 1)
	if _selected >= 0 and _try_slide_to(_selected, row, col):
		return
	_selected = _find_block_at(row, col)
	_grid_ctrl.queue_redraw()

func _find_block_at(row: int, col: int) -> int:
	for i in range(_blocks.size()):
		if _cell_in_block(row, col, _blocks[i]):
			return i
	return -1

func _cell_in_block(row: int, col: int, b: Dictionary) -> bool:
	if b.horiz:
		return row == b.r and col >= b.c and col < b.c + b.len
	else:
		return col == b.c and row >= b.r and row < b.r + b.len

func _try_slide_to(idx: int, tr: int, tc: int) -> bool:
	var b: Dictionary = _blocks[idx]
	if b.horiz:
		if tr != b.r:
			_selected = -1
			_grid_ctrl.queue_redraw()
			return false
		if tc >= b.c and tc < b.c + b.len:
			return false
		var new_c := tc if tc < b.c else tc - b.len + 1
		new_c = clampi(new_c, 0, GRID_COLS - b.len)
		if not _can_slide_h(idx, new_c):
			return false
		_blocks[idx].c = new_c
	else:
		if tc != b.c:
			_selected = -1
			_grid_ctrl.queue_redraw()
			return false
		if tr >= b.r and tr < b.r + b.len:
			return false
		var new_r := tr if tr < b.r else tr - b.len + 1
		new_r = clampi(new_r, 0, GRID_ROWS - b.len)
		if not _can_slide_v(idx, new_r):
			return false
		_blocks[idx].r = new_r
	_grid_ctrl.queue_redraw()
	_check_win()
	return true

func _can_slide_h(idx: int, new_c: int) -> bool:
	var b: Dictionary = _blocks[idx]
	var lo := mini(b.c, new_c)
	var hi := maxi(b.c + b.len - 1, new_c + b.len - 1)
	for i in range(_blocks.size()):
		if i == idx:
			continue
		for dc in range(lo, hi + 1):
			if _cell_in_block(b.r, dc, _blocks[i]):
				return false
	return true

func _can_slide_v(idx: int, new_r: int) -> bool:
	var b: Dictionary = _blocks[idx]
	var lo := mini(b.r, new_r)
	var hi := maxi(b.r + b.len - 1, new_r + b.len - 1)
	for i in range(_blocks.size()):
		if i == idx:
			continue
		for dr in range(lo, hi + 1):
			if _cell_in_block(dr, b.c, _blocks[i]):
				return false
	return true

func _check_win() -> void:
	for i in range(_blocks.size()):
		var b: Dictionary = _blocks[i]
		if b.amulet and b.r == EXIT_ROW and b.c + b.len >= GRID_COLS:
			_on_solved()
			return

func _on_solved() -> void:
	_can_interact = false
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.4, 1.4, 0.8), 0.4)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.5)
	await tw.finished
	await get_tree().create_timer(0.5).timeout
	minigame_completed.emit("unblock")
	queue_free()

func _on_close() -> void:
	minigame_cancelled.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not _can_interact:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()
		return
	if _selected < 0:
		return
	var b: Dictionary = _blocks[_selected]
	var moved := false
	if b.horiz:
		if event.is_action_pressed("ui_left") and b.c > 0 and _can_slide_h(_selected, b.c - 1):
			_blocks[_selected].c -= 1
			moved = true
		elif event.is_action_pressed("ui_right") and b.c + b.len < GRID_COLS and _can_slide_h(_selected, b.c + 1):
			_blocks[_selected].c += 1
			moved = true
	else:
		if event.is_action_pressed("ui_up") and b.r > 0 and _can_slide_v(_selected, b.r - 1):
			_blocks[_selected].r -= 1
			moved = true
		elif event.is_action_pressed("ui_down") and b.r + b.len < GRID_ROWS and _can_slide_v(_selected, b.r + 1):
			_blocks[_selected].r += 1
			moved = true
	if moved:
		_check_win()
		_grid_ctrl.queue_redraw()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Verify puzzle solvability manually**

On paper or in game, confirm solution:
1. Select block A (row 1, col 2). Click row 3, col 2 → slides down, clears (2,2).
2. Select block B (row 1, col 3). Click row 3, col 3 → slides down, clears (2,3).
3. Select block D (row 2, col 4). Click row 4, col 4 → slides down, clears (2,4).
4. Select Amulet (row 2, col 0). Click row 2, col 5 → slides right to (2,4)-(2,5) → triggers win.

- [ ] **Step 3: Commit**
```
git add scripts/minigames/minigame_unblock.gd
git commit -m "feat: MinigameUnblock sliding-block puzzle"
```

---

### Task 7: Rework room_main_hall_logic.gd

**Files:**
- Modify: `scripts/rooms/room_main_hall_logic.gd`

Removes Damper and WoodPickable. Kamyolk examine → open puzzle (if not solved) or light fire (if solved). After puzzle → amulet visible. BackZone added for loop reaction.

- [ ] **Step 1: Replace the entire file**

Replace `scripts/rooms/room_main_hall_logic.gd` with:
```gdscript
extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
var _idle_subtitle_timer: float = 0.0
var _idle_subtitle_shown: bool = false
var _puzzle_solved: bool = false
var _back_trigger_count: int = 0
const CORRECT_ORDER: Array[String] = ["amulet", "doll", "earring"]
const ARTIFACT_NAMES: Dictionary = {
	"amulet": "харысхал",
	"doll": "куклу",
	"earring": "серёжку"
}

func _ready() -> void:
	_apply_loop_visuals()
	_setup_puzzle()
	_add_back_zone()

	if _all_artifacts_collected():
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Ты дошёл.", SubtitleManager.Pos.TOP_CENTER)

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(func(body: Node2D):
			if not body.is_in_group("player"):
				return
			if not GameManager.artifacts_collected.has("amulet"):
				SubtitleManager.show_subtitle("Что-то не отпускает меня.", SubtitleManager.Pos.MID_LEFT)
				return
			GameManager.change_room("door_right")
		)

func _setup_puzzle() -> void:
	var amulet_done := GameManager.artifacts_collected.has("amulet")

	for node_name in ["Damper", "WoodPickable"]:
		var n := get_node_or_null(node_name)
		if n:
			n.queue_free()

	if amulet_done:
		var amulet_node := get_node_or_null("AmuletPickable")
		if amulet_node:
			amulet_node.queue_free()
		kamylok_state = KamylokState.BURNING
		_puzzle_solved = true
	else:
		var amulet_node := get_node_or_null("AmuletPickable")
		if amulet_node:
			amulet_node.visible = false
			amulet_node.picked_up.connect(func(_id): _on_amulet_picked_up())

	if _all_artifacts_collected():
		kamylok_state = KamylokState.RITUAL_READY

	var kamylok := get_node_or_null("Kamyolk")
	if kamylok:
		kamylok.examined.connect(_on_kamylok_examined)

	var riddle := get_node_or_null("RiddleKamyolk")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_kamyolk"))

	var fox_carving := get_node_or_null("FoxRiddleCarving")
	if fox_carving:
		fox_carving.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_kamyolk"))

	var poem := get_node_or_null("RitualPoem")
	if poem:
		poem.examined.connect(func(): DialogueManager.start_dialogue("notes/poem_ritual"))

	for note_data: Array in [
			["NoteEnv1", "notes/note_env_1", "note_env_1"],
			["NoteEnv5", "notes/note_env_5", "note_env_5"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		var note_id: String = note_data[2]
		if note:
			note.examined.connect(func():
				DialogueManager.start_dialogue(key)
				GameManager.mark_note_found(note_id)
			)

func _all_artifacts_collected() -> bool:
	for id in ["amulet", "doll", "earring"]:
		if not GameManager.artifacts_collected.has(id):
			return false
	return true

func _apply_loop_visuals() -> void:
	var ls := GameManager.loop_state
	var fallen := get_node_or_null("LoopFallenPicture")
	if fallen:
		fallen.visible = ls >= 1
	var wall_text := get_node_or_null("LoopWallText")
	if wall_text:
		wall_text.visible = ls >= 2

func _on_kamylok_examined() -> void:
	if kamylok_state == KamylokState.RITUAL_ACTIVE:
		_place_ritual_artifact()
		return
	if kamylok_state == KamylokState.COLD:
		if not _puzzle_solved:
			DialogueManager.show_text("", "Под золой — что-то есть. Дрова завалили вход.")
			await DialogueManager.dialogue_finished
			_open_puzzle()
			return
		else:
			DialogueManager.show_text("", "Угли холодные. Можно разжечь.")
			await DialogueManager.dialogue_finished
			kamylok_state = KamylokState.BURNING
			await _fire_lit()
			return
	if kamylok_state == KamylokState.BURNING:
		DialogueManager.show_text("", "Огонь горит ровно. Тепло наконец.")
		return
	if kamylok_state == KamylokState.RITUAL_READY:
		DialogueManager.show_text("", "Пламя стало другим — тихое, почти прозрачное. Ждёт даров.")
		await DialogueManager.dialogue_finished
		kamylok_state = KamylokState.RITUAL_ACTIVE
		DialogueManager.show_text("", "Пламя ждёт.")

func _open_puzzle() -> void:
	var puzzle := MinigameUnblock.new()
	add_child(puzzle)
	puzzle.minigame_completed.connect(_on_puzzle_solved)
	puzzle.minigame_cancelled.connect(puzzle.queue_free)

func _on_puzzle_solved(_id: String) -> void:
	_puzzle_solved = true
	DialogueManager.show_text("", "Под золой — что-то блестит.")
	await DialogueManager.dialogue_finished
	var amulet_node := get_node_or_null("AmuletPickable")
	if amulet_node:
		amulet_node.visible = true
		amulet_node.set_deferred("monitoring", true)

func _fire_lit() -> void:
	DialogueManager.show_text("", "Огонь занимается медленно, потом ярко — камелёк снова живёт.")
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(2.0).timeout

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	DialogueManager.show_text("", "Харысхал. Косточка, тёплая на ощупь — будто жила в огне все эти годы.")
	await DialogueManager.dialogue_finished
	_show_kydaana_spirit()

func _show_kydaana_spirit() -> void:
	var silhouette := Sprite2D.new()
	var tex_path := "res://assets/sprites/ghost_figure.webp"
	if ResourceLoader.exists(tex_path):
		silhouette.texture = load(tex_path)
	silhouette.modulate = Color(0.2, 0.2, 0.5, 0.0)
	silhouette.position = Vector2(1400, 200)
	silhouette.scale = Vector2(1.8, 1.8)
	add_child(silhouette)
	var tw := create_tween()
	tw.tween_property(silhouette, "modulate:a", 0.75, 2.5)
	tw.tween_interval(5.0)
	tw.tween_property(silhouette, "modulate:a", 0.0, 2.0)
	await tw.finished
	silhouette.queue_free()

func _place_ritual_artifact() -> void:
	var selected := Inventory.selected_item
	if selected.is_empty() or not CORRECT_ORDER.has(selected):
		DialogueManager.show_text("", "Открой инвентарь (I), выбери один из трёх даров, затем подойди к камельку.")
		return
	if ritual_items.has(selected):
		DialogueManager.show_text("", "Этот дар уже в огне.")
		return
	ritual_items.append(selected)
	Inventory.remove_item(selected)
	var count := ritual_items.size()
	DialogueManager.show_text("", "Ты кладёшь %s в огонь. (%d из 3)" % [ARTIFACT_NAMES.get(selected, selected), count])
	await DialogueManager.dialogue_finished
	if count >= 3:
		_complete_ritual()

func _complete_ritual() -> void:
	if ritual_items == CORRECT_ORDER:
		var bg := get_node_or_null("Background") as ColorRect
		if bg:
			var tween := create_tween()
			tween.tween_property(bg, "color", Color(1.0, 0.95, 0.8), 0.8)
			await tween.finished
		DialogueManager.show_text("", "Пламя вспыхивает белым. Стены перестают дрожать. Что-то освобождается.")
		await DialogueManager.dialogue_finished
		SubtitleManager.show_subtitle("Я не думала что кто-то придёт.", SubtitleManager.Pos.BOTTOM_CENTER)
		await get_tree().create_timer(4.0).timeout
		GameManager.start_finale("good")
	else:
		DialogueManager.show_text("", "Огонь гаснет. Тишина становится абсолютной.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("bad")

func _add_back_zone() -> void:
	var area := Area2D.new()
	area.name = "BackZone"
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 400)
	shape.position = Vector2(0, 180)
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_back_zone)

func _on_back_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_back_trigger_count += 1
	DialogueManager.show_text("", _get_loop_text(_back_trigger_count))
	await DialogueManager.dialogue_finished
	GameManager.change_room("door_exit")

func _get_loop_text(count: int) -> String:
	match count:
		1: return "Снова здесь. Что-то не пускает."
		2: return "Та же дверь. Тот же коридор."
		_: return "Я хожу по кругу."

func _process(delta: float) -> void:
	if _idle_subtitle_shown:
		return
	_idle_subtitle_timer += delta
	if _idle_subtitle_timer >= 10.0:
		_idle_subtitle_shown = true
		SubtitleManager.show_subtitle("Холодно.", SubtitleManager.Pos.MID_RIGHT)
```

- [ ] **Step 2: Commit**
```
git add scripts/rooms/room_main_hall_logic.gd
git commit -m "feat: main_hall puzzle flow — unblock puzzle reveals amulet, remove damper, add BackZone"
```
