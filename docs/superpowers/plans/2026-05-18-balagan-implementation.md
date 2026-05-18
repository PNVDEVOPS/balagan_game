# Балаган — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable 15-20 minute horror-adventure demo in Godot 4.3+ — 6 rooms, 3 artifacts, flashlight mechanic, spirit dog guide, stealth, and dialogue.

**Architecture:** Room-Scene architecture — each room is an independent `.tscn` scene. Transitions via `GameManager` autoload that reads a JSON room graph and supports runtime mutation for "space distortion." Player, inventory, audio, and dialogue are global autoloads that persist across scene changes.

**Tech Stack:** Godot 4.3+, GDScript, 640x360 base resolution (3x scale to 1920x1080), JSON for data.

**Note on testing:** Godot games are verified by running the project (F5) and checking behavior visually. Each task includes "Run and verify" steps instead of unit tests.

---

## File Map

```
balagan/
├── project.godot
├── assets/
│   ├── sprites/
│   │   ├── player_placeholder.png       (32x64 colored rectangle)
│   │   ├── laika_placeholder.png        (24x20 colored rectangle)
│   │   ├── spirit_placeholder.png       (32x48 dark rectangle)
│   │   ├── door_placeholder.png         (20x48 rectangle)
│   │   ├── item_placeholder.png         (16x16 square)
│   │   └── interaction_prompt.png       (32x16 "[E]" icon)
│   ├── audio/                           (placeholder .wav files)
│   └── fonts/
├── scenes/
│   ├── player/
│   │   └── player.tscn                  → scripts/player/player.gd
│   ├── characters/
│   │   ├── laika.tscn                   → scripts/characters/laika.gd
│   │   └── spirit_guardian.tscn         → scripts/characters/spirit_guardian.gd
│   ├── objects/
│   │   ├── door.tscn                    → scripts/objects/door.gd
│   │   ├── pickable.tscn               → scripts/objects/pickable.gd
│   │   ├── examinable.tscn             → scripts/objects/examinable.gd
│   │   ├── usable.tscn                 → scripts/objects/usable.gd
│   │   └── hideable.tscn              → scripts/objects/hideable.gd
│   ├── ui/
│   │   ├── hud.tscn                     → scripts/ui/hud.gd
│   │   ├── dialogue_box.tscn           → scripts/ui/dialogue_box.gd
│   │   ├── inventory_ui.tscn           → scripts/ui/inventory_ui.gd
│   │   ├── qte_overlay.tscn            → scripts/ui/qte_overlay.gd
│   │   └── screen_fade.tscn            → scripts/ui/screen_fade.gd
│   └── rooms/
│       ├── room_entrance.tscn
│       ├── room_main_hall.tscn
│       ├── room_bedroom.tscn
│       ├── room_corridor.tscn
│       ├── room_storage.tscn
│       └── room_basement.tscn
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd
│   │   ├── inventory.gd
│   │   ├── audio_manager.gd
│   │   └── dialogue_manager.gd
│   ├── player/
│   │   ├── player.gd
│   │   └── flashlight.gd
│   ├── characters/
│   │   ├── laika.gd
│   │   └── spirit_guardian.gd
│   ├── objects/
│   │   ├── interactable.gd              (base class)
│   │   ├── door.gd
│   │   ├── pickable.gd
│   │   ├── examinable.gd
│   │   ├── usable.gd
│   │   └── hideable.gd
│   └── ui/
│       ├── hud.gd
│       ├── dialogue_box.gd
│       ├── inventory_ui.gd
│       ├── qte_overlay.gd
│       └── screen_fade.gd
└── data/
    ├── room_graph.json
    └── dialogues/
        ├── intro.json
        ├── examine_texts.json
        ├── artifact_1.json
        ├── artifact_2.json
        ├── artifact_3.json
        └── finale.json
```

---

## Task 1: Project Setup + Player Movement

**Files:**
- Create: `project.godot`
- Create: `scripts/player/player.gd`
- Create: `scenes/player/player.tscn` (via Godot editor)
- Create: `assets/sprites/player_placeholder.png` (via code — simple image)

### Steps

- [ ] **Step 1: Create Godot project file**

Create `project.godot` with correct settings:

```ini
; Engine configuration file.
; It's best edited using the editor UI and not directly,
; but it can also be edited using a text editor.

config_version=5

[application]

config/name="Балаган"
run/main_scene="res://scenes/rooms/room_main_hall.tscn"
config/features=PackedStringArray("4.3", "GL Compatibility")

[autoload]

GameManager="*res://scripts/autoload/game_manager.gd"
Inventory="*res://scripts/autoload/inventory.gd"
AudioManager="*res://scripts/autoload/audio_manager.gd"
DialogueManager="*res://scripts/autoload/dialogue_manager.gd"

[display]

window/size/viewport_width=640
window/size/viewport_height=360
window/size/window_width_override=1920
window/size/window_height_override=1080
window/stretch/mode="viewport"

[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194319,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194321,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
run={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194325,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":69,"key_label":0,"unicode":101,"location":0,"echo":false,"script":null)
]
}
hide={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":81,"key_label":0,"unicode":113,"location":0,"echo":false,"script":null)
]
}
inventory={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194306,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":73,"key_label":0,"unicode":105,"location":0,"echo":false,"script":null)
]
}
advance_dialogue={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":32,"location":0,"echo":false,"script":null)
, Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194309,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}

[rendering]

textures/canvas_textures/default_texture_filter=0
```

Note: `default_texture_filter=0` sets Nearest Neighbor filtering — critical for pixel art to stay sharp.

Input mappings: A/Left = move_left, D/Right = move_right, Shift = run, E = interact, Q = hide, Tab/I = inventory, Space/Enter = advance_dialogue.

- [ ] **Step 2: Create placeholder autoload scripts**

Create minimal autoloads so the project loads without errors:

`scripts/autoload/game_manager.gd`:
```gdscript
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
```

`scripts/autoload/inventory.gd`:
```gdscript
extends Node

signal item_added(item_id: String)
signal item_removed(item_id: String)
signal inventory_changed()

const MAX_SLOTS := 8

var items: Array[String] = []
var selected_item: String = ""

func add_item(item_id: String) -> bool:
	if items.size() >= MAX_SLOTS:
		return false
	if items.has(item_id):
		return false
	items.append(item_id)
	item_added.emit(item_id)
	inventory_changed.emit()
	return true

func remove_item(item_id: String) -> void:
	items.erase(item_id)
	if selected_item == item_id:
		selected_item = ""
	item_removed.emit(item_id)
	inventory_changed.emit()

func has_item(item_id: String) -> bool:
	return items.has(item_id)

func select_item(item_id: String) -> void:
	if items.has(item_id):
		selected_item = item_id

func clear_selection() -> void:
	selected_item = ""
```

`scripts/autoload/audio_manager.gd`:
```gdscript
extends Node

var ambient_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

func _ready() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	add_child(ambient_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	add_child(sfx_player)

func play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()

func play_ambient(stream: AudioStream) -> void:
	ambient_player.stream = stream
	ambient_player.play()

func stop_ambient() -> void:
	ambient_player.stop()
```

`scripts/autoload/dialogue_manager.gd`:
```gdscript
extends Node

signal dialogue_started()
signal dialogue_line(speaker: String, text: String)
signal dialogue_finished()

var is_active: bool = false
var current_lines: Array = []
var current_index: int = 0

func start_dialogue(dialogue_id: String) -> void:
	var path := "res://data/dialogues/%s.json" % dialogue_id
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	json.parse(file.get_as_text())
	file.close()
	current_lines = json.data.get("lines", [])
	current_index = 0
	is_active = true
	dialogue_started.emit()
	_show_next_line()

func advance() -> void:
	if not is_active:
		return
	current_index += 1
	if current_index >= current_lines.size():
		is_active = false
		dialogue_finished.emit()
		return
	_show_next_line()

func _show_next_line() -> void:
	var line: Dictionary = current_lines[current_index]
	dialogue_line.emit(line.get("speaker", ""), line.get("text", ""))

func show_text(speaker: String, text: String) -> void:
	current_lines = [{"speaker": speaker, "text": text}]
	current_index = 0
	is_active = true
	dialogue_started.emit()
	_show_next_line()
```

- [ ] **Step 3: Create room graph data**

`data/room_graph.json`:
```json
{
  "rooms": {
    "entrance": {
      "scene": "res://scenes/rooms/room_entrance.tscn",
      "doors": {
        "door_inside": "main_hall"
      }
    },
    "main_hall": {
      "scene": "res://scenes/rooms/room_main_hall.tscn",
      "doors": {
        "door_entrance": "entrance",
        "door_left": "bedroom",
        "door_right": "corridor"
      }
    },
    "bedroom": {
      "scene": "res://scenes/rooms/room_bedroom.tscn",
      "doors": {
        "door_back": "main_hall"
      }
    },
    "corridor": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": {
        "door_left": "main_hall",
        "door_right": "storage",
        "door_down": "basement"
      }
    },
    "storage": {
      "scene": "res://scenes/rooms/room_storage.tscn",
      "doors": {
        "door_back": "corridor"
      }
    },
    "basement": {
      "scene": "res://scenes/rooms/room_basement.tscn",
      "doors": {
        "door_up": "corridor"
      }
    }
  }
}
```

- [ ] **Step 4: Create player script**

`scripts/player/player.gd`:
```gdscript
extends CharacterBody2D

const WALK_SPEED := 80.0
const RUN_SPEED := 140.0
const GRAVITY := 600.0

var facing_right := true
var is_interacting := false
var is_hiding := false
var nearest_interactable: Node2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray: RayCast2D = $InteractionRay
@onready var flashlight: PointLight2D = $Flashlight
@onready var camera: Camera2D = $Camera2D
@onready var prompt: Sprite2D = $InteractionPrompt

func _ready() -> void:
	prompt.visible = false

func _physics_process(delta: float) -> void:
	if is_hiding or is_interacting:
		velocity.x = 0
	else:
		_handle_movement()

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0

	move_and_slide()
	_update_animation()
	_check_interaction()

func _handle_movement() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var is_running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if is_running else WALK_SPEED

	velocity.x = direction * speed

	if direction > 0:
		facing_right = true
		sprite.flip_h = false
		ray.target_position = Vector2(30, 0)
	elif direction < 0:
		facing_right = false
		sprite.flip_h = true
		ray.target_position = Vector2(-30, 0)

func _update_animation() -> void:
	if is_hiding:
		return
	if is_interacting:
		sprite.play("crank")
		return
	if abs(velocity.x) < 1.0:
		sprite.play("idle")
	elif Input.is_action_pressed("run"):
		sprite.play("run")
	else:
		sprite.play("walk")

func _check_interaction() -> void:
	if ray.is_colliding():
		var collider := ray.get_collider()
		if collider and collider.has_method("get_interaction_type"):
			nearest_interactable = collider
			prompt.visible = true
			return
	nearest_interactable = null
	prompt.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and nearest_interactable:
		if nearest_interactable.has_method("interact"):
			nearest_interactable.interact(self)
	elif event.is_action_pressed("hide") and nearest_interactable:
		if nearest_interactable.has_method("hide_player"):
			nearest_interactable.hide_player(self)
	elif event.is_action_pressed("advance_dialogue"):
		if DialogueManager.is_active:
			DialogueManager.advance()
```

- [ ] **Step 5: Create player scene in Godot editor**

Open Godot editor, create new scene `scenes/player/player.tscn`:

1. Root node: **CharacterBody2D** (rename to "Player")
2. Add child: **CollisionShape2D** — shape: RectangleShape2D (16x64)
3. Add child: **AnimatedSprite2D** — create SpriteFrames resource, add animations: `idle` (1 frame), `walk` (1 frame), `run` (1 frame), `crank` (1 frame). Use player_placeholder.png for all frames for now.
4. Add child: **PointLight2D** (rename to "Flashlight") — texture: default gradient, energy: 1.0, range: set texture_scale to 2.0, color: warm yellow (#FFF4D6)
5. Add child: **RayCast2D** (rename to "InteractionRay") — target_position: (30, 0), enabled: true, collision_mask: layer 2
6. Add child: **Sprite2D** (rename to "InteractionPrompt") — use interaction_prompt.png, position: (0, -40), visible: false
7. Add child: **Camera2D** — zoom: (1, 1), position_smoothing_enabled: true
8. Attach script: `res://scripts/player/player.gd`
9. Set Player collision layer to 1, collision mask to 1+2

- [ ] **Step 6: Create a test room scene**

Create `scenes/rooms/room_main_hall.tscn` in editor:

1. Root node: **Node2D** (rename to "RoomMainHall")
2. Add child: **StaticBody2D** (rename to "Floor") — add CollisionShape2D with WorldBoundaryShape2D or RectangleShape2D, position at y=320 (near bottom of 640x360 viewport)
3. Add child: **ColorRect** (rename to "Background") — size: 640x360, color: dark brown (#1A0F0A), anchors: full rect
4. Add child: **ColorRect** (rename to "FloorVisual") — size: 640x40, position: (0, 320), color: dark wood (#2D1B10)
5. Instance player scene: drag `scenes/player/player.tscn` into the room, position at (100, 300)

- [ ] **Step 7: Run and verify**

Run: Press F5 in Godot editor.
Expected:
- Window opens at 1920x1080 with pixel-art scaling
- Player (colored rectangle) stands on a dark floor
- A/D or arrows move player left/right
- Shift makes player move faster
- Player faces direction of movement
- Flashlight illuminates area around player

- [ ] **Step 8: Commit**

```bash
git init
git add -A
git commit -m "feat: project setup with player movement, autoloads, and room graph"
```

---

## Task 2: Screen Fade + Room Transitions

**Files:**
- Create: `scripts/ui/screen_fade.gd`
- Create: `scenes/ui/screen_fade.tscn` (via editor)
- Modify: `scripts/autoload/game_manager.gd`
- Create: `scenes/rooms/room_entrance.tscn` (via editor)
- Create: `scenes/rooms/room_bedroom.tscn` (via editor)

### Steps

- [ ] **Step 1: Create screen fade script**

`scripts/ui/screen_fade.gd`:
```gdscript
extends CanvasLayer

@onready var color_rect: ColorRect = $ColorRect

var tween: Tween

func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func fade_out(duration: float = 0.5) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.5) -> void:
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
```

- [ ] **Step 2: Create screen fade scene in editor**

Create `scenes/ui/screen_fade.tscn`:

1. Root: **CanvasLayer** (rename to "ScreenFade") — layer: 10 (above everything)
2. Add child: **ColorRect** — anchors: full rect (Layout → Full Rect), color: black (#000000), alpha: 0
3. Attach script: `res://scripts/ui/screen_fade.gd`

- [ ] **Step 3: Update GameManager with fade transitions**

Replace `scripts/autoload/game_manager.gd`:
```gdscript
extends Node

signal room_changed(room_id: String)
signal artifact_collected(artifact_id: String)

var current_room: String = "main_hall"
var artifacts_collected: Array[String] = []
var room_graph: Dictionary = {}
var transition_count: int = 0
var is_transitioning: bool = false

var _room_graph_original: Dictionary = {}
var _screen_fade: Node = null

func _ready() -> void:
	_load_room_graph()

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

	_ensure_fade()
	await _screen_fade.fade_out(0.5)

	current_room = target_room
	transition_count += 1
	get_tree().change_scene_to_file(scene_path)

	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_fade()
	await _screen_fade.fade_in(0.5)

	is_transitioning = false
	room_changed.emit(target_room)

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
```

- [ ] **Step 4: Create two more test rooms**

Create `scenes/rooms/room_entrance.tscn` in editor:
1. Root: **Node2D** (rename to "RoomEntrance")
2. Add: **StaticBody2D** floor at y=320
3. Add: **ColorRect** background — color: very dark (#0D0805)
4. Add: **ColorRect** floor visual — dark wood
5. Instance player at (100, 300)
6. (Door objects added in Task 3)

Create `scenes/rooms/room_bedroom.tscn` — same structure, different background color (#1A0D12 — slightly purple/cold).

- [ ] **Step 5: Run and verify**

At this point you can't test transitions yet (no door objects), but verify:
- Room loads without errors
- ScreenFade can be tested by calling `GameManager.change_room()` from a temporary button or `_ready()` script

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/screen_fade.gd scripts/autoload/game_manager.gd data/room_graph.json
git commit -m "feat: screen fade and room transition system with graph-based routing"
```

---

## Task 3: Interaction System + Doors

**Files:**
- Create: `scripts/objects/interactable.gd`
- Create: `scripts/objects/door.gd`
- Create: `scenes/objects/door.tscn` (via editor)

### Steps

- [ ] **Step 1: Create base interactable script**

`scripts/objects/interactable.gd`:
```gdscript
class_name Interactable
extends Area2D

enum Type { DOOR, PICKABLE, EXAMINABLE, USABLE, TRIGGER, HIDEABLE }

@export var interaction_type: Type = Type.EXAMINABLE
@export var interaction_text: String = ""
@export var required_item: String = ""

func get_interaction_type() -> Type:
	return interaction_type

func interact(player: CharacterBody2D) -> void:
	pass

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(2, true)
```

- [ ] **Step 2: Create door script**

`scripts/objects/door.gd`:
```gdscript
extends Interactable

@export var door_id: String = ""
@export var locked: bool = false
@export var lock_message: String = "Дверь заперта..."

func _ready() -> void:
	super._ready()
	interaction_type = Type.DOOR

func interact(player: CharacterBody2D) -> void:
	if locked:
		if not required_item.is_empty() and Inventory.has_item(required_item):
			locked = false
			Inventory.remove_item(required_item)
			DialogueManager.show_text("", "Дверь открылась.")
			await DialogueManager.dialogue_finished
			GameManager.change_room(door_id)
		else:
			DialogueManager.show_text("", lock_message)
	else:
		GameManager.change_room(door_id)
```

- [ ] **Step 3: Create door scene in editor**

Create `scenes/objects/door.tscn`:

1. Root: **Area2D** (rename to "Door")
2. Add child: **CollisionShape2D** — shape: RectangleShape2D (20x48)
3. Add child: **Sprite2D** — use door_placeholder.png (20x48 rectangle, dark gray)
4. Attach script: `res://scripts/objects/door.gd`
5. Set collision layer: 2, collision mask: 1

- [ ] **Step 4: Place doors in test rooms**

In `room_main_hall.tscn`:
1. Instance `scenes/objects/door.tscn` — position: (30, 296), set door_id = "door_entrance"
2. Instance again — position: (150, 296), set door_id = "door_left"
3. Instance again — position: (500, 296), set door_id = "door_right"

In `room_entrance.tscn`:
1. Instance door — position: (500, 296), door_id = "door_inside"
2. Instance door — position: (30, 296), door_id = "door_outside", locked = true, lock_message = "Дверь не поддаётся... Снаружи метель."

In `room_bedroom.tscn`:
1. Instance door — position: (500, 296), door_id = "door_back"

- [ ] **Step 5: Run and verify**

Run F5:
- Walk to door → "[E]" prompt appears
- Press E → screen fades out → new room loads → fades in
- Player appears in new room
- Locked door shows message "Дверь не поддаётся..."
- Can navigate between main_hall ↔ entrance ↔ bedroom

- [ ] **Step 6: Commit**

```bash
git add scripts/objects/interactable.gd scripts/objects/door.gd scenes/objects/door.tscn
git commit -m "feat: interaction system with door transitions between rooms"
```

---

## Task 4: Pickable, Examinable + Inventory UI

**Files:**
- Create: `scripts/objects/pickable.gd`
- Create: `scripts/objects/examinable.gd`
- Create: `scripts/objects/usable.gd`
- Create: `scripts/ui/inventory_ui.gd`
- Create: `scenes/ui/inventory_ui.tscn` (via editor)
- Create: `scripts/ui/hud.gd`
- Create: `scenes/ui/hud.tscn` (via editor)

### Steps

- [ ] **Step 1: Create pickable script**

`scripts/objects/pickable.gd`:
```gdscript
extends Interactable

@export var item_id: String = ""
@export var item_name: String = ""
@export var pickup_text: String = ""

func _ready() -> void:
	super._ready()
	interaction_type = Type.PICKABLE
	if Inventory.has_item(item_id):
		queue_free()

func interact(player: CharacterBody2D) -> void:
	if Inventory.add_item(item_id):
		if not pickup_text.is_empty():
			DialogueManager.show_text("", pickup_text)
		queue_free()
```

- [ ] **Step 2: Create examinable script**

`scripts/objects/examinable.gd`:
```gdscript
extends Interactable

@export_multiline var examine_text: String = ""

func _ready() -> void:
	super._ready()
	interaction_type = Type.EXAMINABLE

func interact(player: CharacterBody2D) -> void:
	if not examine_text.is_empty():
		DialogueManager.show_text("", examine_text)
```

- [ ] **Step 3: Create usable script**

`scripts/objects/usable.gd`:
```gdscript
extends Interactable

@export var success_text: String = ""
@export var fail_text: String = "Нужно что-то для этого..."
@export var used: bool = false

signal item_used()

func _ready() -> void:
	super._ready()
	interaction_type = Type.USABLE

func interact(player: CharacterBody2D) -> void:
	if used:
		return
	if required_item.is_empty():
		_on_success()
		return
	if Inventory.selected_item == required_item:
		Inventory.remove_item(required_item)
		_on_success()
	elif not Inventory.selected_item.is_empty():
		DialogueManager.show_text("", "Это здесь не подходит.")
	else:
		DialogueManager.show_text("", fail_text)

func _on_success() -> void:
	used = true
	if not success_text.is_empty():
		DialogueManager.show_text("", success_text)
	item_used.emit()
```

- [ ] **Step 4: Create inventory UI script**

`scripts/ui/inventory_ui.gd`:
```gdscript
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var item_list: HBoxContainer = $Panel/MarginContainer/HBoxContainer

var is_open: bool = false
var slot_scene: PackedScene

func _ready() -> void:
	panel.visible = false
	Inventory.inventory_changed.connect(_refresh)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()

func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	if is_open:
		_refresh()

func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for item_id in Inventory.items:
		var btn := Button.new()
		btn.text = item_id
		btn.custom_minimum_size = Vector2(64, 64)
		if Inventory.selected_item == item_id:
			btn.modulate = Color.YELLOW
		btn.pressed.connect(_on_item_pressed.bind(item_id))
		item_list.add_child(btn)

func _on_item_pressed(item_id: String) -> void:
	if Inventory.selected_item == item_id:
		Inventory.clear_selection()
	else:
		Inventory.select_item(item_id)
	_refresh()
```

- [ ] **Step 5: Create inventory UI scene in editor**

Create `scenes/ui/inventory_ui.tscn`:

1. Root: **CanvasLayer** (rename to "InventoryUI") — layer: 5
2. Add child: **PanelContainer** (rename to "Panel") — anchors: bottom-center, size: (500, 80), position near bottom of screen, visible: false
3. Inside Panel add: **MarginContainer** — margins: 8px all sides
4. Inside MarginContainer add: **HBoxContainer** — alignment: center, separation: 8
5. Attach script: `res://scripts/ui/inventory_ui.gd`

- [ ] **Step 6: Create HUD script**

`scripts/ui/hud.gd`:
```gdscript
extends CanvasLayer

@onready var inventory_ui: CanvasLayer = $InventoryUI

func _ready() -> void:
	pass
```

- [ ] **Step 7: Create HUD scene in editor**

Create `scenes/ui/hud.tscn`:

1. Root: **CanvasLayer** (rename to "HUD") — layer: 5
2. Instance `scenes/ui/inventory_ui.tscn` as child
3. Attach script: `res://scripts/ui/hud.gd`

Add HUD to each room scene as a child of the root node.

- [ ] **Step 8: Place test pickable in bedroom**

In `room_bedroom.tscn`:
1. Create new Area2D node, attach `scripts/objects/pickable.gd`
2. Add CollisionShape2D (16x16 rectangle) and Sprite2D (item_placeholder.png)
3. Set item_id = "test_key", pickup_text = "Нашёл старый ключ."
4. Position at (300, 308)

- [ ] **Step 9: Run and verify**

Run F5:
- Go to bedroom, walk to item → "[E]" prompt
- Press E → item disappears, text appears
- Press Tab → inventory panel opens, shows "test_key"
- Click item → turns yellow (selected)
- Tab again → closes
- Walk to locked door with selected item → door unlocks

- [ ] **Step 10: Commit**

```bash
git add scripts/objects/ scripts/ui/ scenes/ui/ scenes/objects/
git commit -m "feat: inventory system with pickable/examinable/usable objects and UI"
```

---

## Task 5: Dialogue Box UI

**Files:**
- Create: `scripts/ui/dialogue_box.gd`
- Create: `scenes/ui/dialogue_box.tscn` (via editor)
- Modify: `scenes/ui/hud.tscn` — add dialogue box

### Steps

- [ ] **Step 1: Create dialogue box script**

`scripts/ui/dialogue_box.gd`:
```gdscript
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var speaker_label: Label = $Panel/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/VBoxContainer/TextLabel

var full_text: String = ""
var char_index: int = 0
var typewriter_speed: float = 0.03
var is_typing: bool = false

func _ready() -> void:
	panel.visible = false
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_line.connect(_on_dialogue_line)
	DialogueManager.dialogue_finished.connect(_on_dialogue_finished)

func _on_dialogue_started() -> void:
	panel.visible = true

func _on_dialogue_line(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	speaker_label.visible = not speaker.is_empty()
	full_text = text
	text_label.text = ""
	char_index = 0
	is_typing = true

func _on_dialogue_finished() -> void:
	panel.visible = false
	is_typing = false

func _process(delta: float) -> void:
	if not is_typing:
		return
	char_index += 1
	if char_index >= full_text.length():
		text_label.text = full_text
		is_typing = false
		return
	text_label.text = full_text.substr(0, char_index)

func _unhandled_input(event: InputEvent) -> void:
	if not panel.visible:
		return
	if event.is_action_pressed("advance_dialogue"):
		if is_typing:
			text_label.text = full_text
			is_typing = false
		else:
			DialogueManager.advance()
		get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Create dialogue box scene in editor**

Create `scenes/ui/dialogue_box.tscn`:

1. Root: **CanvasLayer** (rename to "DialogueBox") — layer: 8
2. Add child: **PanelContainer** (rename to "Panel") — anchors: bottom-wide, custom_minimum_size: (0, 80), visible: false, self_modulate: Color(0.1, 0.08, 0.06, 0.85)
3. Inside Panel: **VBoxContainer**
4. Inside VBox: **Label** (rename to "SpeakerLabel") — uppercase: true, font_size: 12, modulate: warm yellow
5. Inside VBox: **RichTextLabel** (rename to "TextLabel") — fit_content: true, font_size: 14, scroll_active: false
6. Attach script: `res://scripts/ui/dialogue_box.gd`

- [ ] **Step 3: Add dialogue box to HUD**

In `scenes/ui/hud.tscn`, instance `scenes/ui/dialogue_box.tscn` as child of root.

- [ ] **Step 4: Run and verify**

Run F5:
- Walk to examinable object → press E
- Dark panel appears at bottom with text typing out letter by letter
- Space → skips to full text
- Space again → dialogue closes
- Walk to pickable → pickup text appears the same way

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/dialogue_box.gd scenes/ui/dialogue_box.tscn scenes/ui/hud.tscn
git commit -m "feat: dialogue box with typewriter effect and speaker names"
```

---

## Task 6: Flashlight Mechanic

**Files:**
- Create: `scripts/player/flashlight.gd`
- Modify: `scripts/player/player.gd` — integrate flashlight

### Steps

- [ ] **Step 1: Create flashlight script**

`scripts/player/flashlight.gd`:
```gdscript
extends PointLight2D

signal charge_depleted()
signal qte_success()
signal qte_failure()

const MAX_CHARGE := 100.0
const DRAIN_RATE := 2.2
const CRANK_AMOUNT := 8.0
const QTE_DRAIN_RATE := 15.0
const QTE_CHARGE_PER_PRESS := 6.0
const QTE_THRESHOLD := 80.0
const QTE_TIMEOUT := 4.0
const LOW_CHARGE := 30.0
const FLICKER_CHANCE := 0.3

var charge: float = MAX_CHARGE
var is_cranking: bool = false
var is_scripted_off: bool = false
var is_qte_active: bool = false
var qte_timer: float = 0.0

var _base_energy: float = 1.5
var _base_scale: float = 2.0
var _flicker_timer: float = 0.0

func _process(delta: float) -> void:
	if is_scripted_off:
		energy = 0.0
		return

	if is_qte_active:
		_process_qte(delta)
		return

	if not is_cranking:
		charge = maxf(charge - DRAIN_RATE * delta, 0.0)

	_update_visuals(delta)

	if charge <= 0.0:
		charge_depleted.emit()

func _process_qte(delta: float) -> void:
	qte_timer -= delta
	charge = maxf(charge - QTE_DRAIN_RATE * delta, 0.0)
	_update_visuals(delta)

	if charge >= QTE_THRESHOLD:
		is_qte_active = false
		charge = MAX_CHARGE
		energy = _base_energy * 3.0
		var tween := create_tween()
		tween.tween_property(self, "energy", _base_energy, 0.5)
		qte_success.emit()
		return

	if qte_timer <= 0.0 or charge <= 0.0:
		is_qte_active = false
		qte_failure.emit()

func _update_visuals(delta: float) -> void:
	var charge_ratio := charge / MAX_CHARGE
	energy = _base_energy * charge_ratio
	texture_scale = _base_scale * (0.5 + 0.5 * charge_ratio)

	if charge < LOW_CHARGE:
		_flicker_timer -= delta
		if _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.1, 0.4)
			if randf() < FLICKER_CHANCE:
				energy *= randf_range(0.2, 0.8)

func crank() -> void:
	if is_scripted_off or is_qte_active:
		return
	is_cranking = true
	charge = minf(charge + CRANK_AMOUNT, MAX_CHARGE)

func stop_crank() -> void:
	is_cranking = false

func qte_press() -> void:
	if is_qte_active:
		charge = minf(charge + QTE_CHARGE_PER_PRESS, MAX_CHARGE)

func start_qte() -> void:
	is_qte_active = true
	charge = 10.0
	qte_timer = QTE_TIMEOUT

func scripted_off() -> void:
	is_scripted_off = true
	energy = 0.0

func scripted_on() -> void:
	is_scripted_off = false

func scripted_flicker(duration: float = 2.0) -> void:
	is_scripted_off = true
	var elapsed := 0.0
	while elapsed < duration:
		energy = randf_range(0.0, _base_energy * 0.5)
		var wait := randf_range(0.05, 0.15)
		await get_tree().create_timer(wait).timeout
		elapsed += wait
	is_scripted_off = false
```

- [ ] **Step 2: Update player script with flashlight integration**

Add to `scripts/player/player.gd`, replace `_unhandled_input`:

```gdscript
@onready var flashlight_ctrl: PointLight2D = $Flashlight

func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active:
		if event.is_action_pressed("advance_dialogue"):
			DialogueManager.advance()
		return

	if flashlight_ctrl.is_qte_active:
		if event.is_action_pressed("interact"):
			flashlight_ctrl.qte_press()
		return

	if event.is_action_pressed("interact"):
		if nearest_interactable:
			nearest_interactable.interact(self)
		else:
			_start_crank()
	elif event.is_action_released("interact"):
		_stop_crank()
	elif event.is_action_pressed("hide") and nearest_interactable:
		if nearest_interactable.has_method("hide_player"):
			nearest_interactable.hide_player(self)

func _start_crank() -> void:
	if nearest_interactable:
		return
	is_interacting = true
	flashlight_ctrl.crank()

func _stop_crank() -> void:
	is_interacting = false
	flashlight_ctrl.stop_crank()
```

- [ ] **Step 3: Attach flashlight script to player scene**

In `scenes/player/player.tscn`:
1. Select the Flashlight (PointLight2D) node
2. Detach any existing script, attach `res://scripts/player/flashlight.gd`
3. Set PointLight2D properties: energy=1.5, texture_scale=2.0, color=#FFF4D6, shadow_enabled=true

- [ ] **Step 4: Run and verify**

Run F5:
- Flashlight illuminates around player
- Wait ~45 seconds — light dims, starts flickering
- Hold E (not near object) — player stops, light recharges
- Release E — player can move again, light starts draining
- Light brightness = visual charge indicator

- [ ] **Step 5: Commit**

```bash
git add scripts/player/flashlight.gd scripts/player/player.gd
git commit -m "feat: dynamo flashlight with charge/drain, crank mechanic, QTE, and scripted control"
```

---

## Task 7: Hiding Mechanic + QTE Overlay

**Files:**
- Create: `scripts/objects/hideable.gd`
- Create: `scenes/objects/hideable.tscn` (via editor)
- Create: `scripts/ui/qte_overlay.gd`
- Create: `scenes/ui/qte_overlay.tscn` (via editor)

### Steps

- [ ] **Step 1: Create hideable script**

`scripts/objects/hideable.gd`:
```gdscript
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
```

- [ ] **Step 2: Create hideable scene in editor**

Create `scenes/objects/hideable.tscn`:

1. Root: **Area2D** (rename to "Hideable")
2. Add: **CollisionShape2D** — RectangleShape2D (32x48)
3. Add: **Sprite2D** — placeholder rectangle (wardrobe/table shape)
4. Attach script: `res://scripts/objects/hideable.gd`
5. Collision layer: 2, mask: 1

- [ ] **Step 3: Create QTE overlay script**

`scripts/ui/qte_overlay.gd`:
```gdscript
extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var prompt_label: Label = $Panel/VBoxContainer/PromptLabel
@onready var charge_bar: ProgressBar = $Panel/VBoxContainer/ChargeBar

var flashlight_ref: Node = null
var shake_intensity: float = 0.0

func _ready() -> void:
	panel.visible = false

func start_qte(flashlight: Node) -> void:
	flashlight_ref = flashlight
	panel.visible = true
	prompt_label.text = "[ E ] [ E ] [ E ]"
	charge_bar.max_value = 100.0
	shake_intensity = 3.0
	flashlight.qte_success.connect(_on_qte_end.bind(true), CONNECT_ONE_SHOT)
	flashlight.qte_failure.connect(_on_qte_end.bind(false), CONNECT_ONE_SHOT)

func _process(_delta: float) -> void:
	if not panel.visible or not flashlight_ref:
		return
	charge_bar.value = flashlight_ref.charge
	if shake_intensity > 0:
		panel.position = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

func _on_qte_end(success: bool) -> void:
	panel.visible = false
	flashlight_ref = null
	shake_intensity = 0.0
	panel.position = Vector2.ZERO
```

- [ ] **Step 4: Create QTE overlay scene in editor**

Create `scenes/ui/qte_overlay.tscn`:

1. Root: **CanvasLayer** (rename to "QTEOverlay") — layer: 9
2. Add: **PanelContainer** (rename to "Panel") — anchors: center, size: (200, 60), visible: false, self_modulate: Color(0.2, 0, 0, 0.8)
3. Inside Panel: **VBoxContainer**
4. Inside VBox: **Label** (rename to "PromptLabel") — text: "[ E ]", horizontal_alignment: center, font_size: 18
5. Inside VBox: **ProgressBar** (rename to "ChargeBar") — max_value: 100, custom_minimum_size: (180, 12)
6. Attach script: `res://scripts/ui/qte_overlay.gd`

- [ ] **Step 5: Add QTE overlay to HUD scene**

In `scenes/ui/hud.tscn`, instance `scenes/ui/qte_overlay.tscn` as child.

- [ ] **Step 6: Run and verify**

- Place a hideable object in a room
- Walk to it → press Q → player disappears (hidden)
- Press Q or E again → player reappears
- (QTE tested in Task 8 with spirits)

- [ ] **Step 7: Commit**

```bash
git add scripts/objects/hideable.gd scripts/ui/qte_overlay.gd scenes/objects/hideable.tscn scenes/ui/qte_overlay.tscn
git commit -m "feat: hiding mechanic and QTE overlay for spirit encounters"
```

---

## Task 8: Spirit Guardian (Enemy AI)

**Files:**
- Create: `scripts/characters/spirit_guardian.gd`
- Create: `scenes/characters/spirit_guardian.tscn` (via editor)

### Steps

- [ ] **Step 1: Create spirit guardian script**

`scripts/characters/spirit_guardian.gd`:
```gdscript
extends CharacterBody2D

const PATROL_SPEED := 30.0
const CHASE_SPEED := 60.0
const DETECTION_RANGE := 80.0
const DETECTION_ANGLE := 60.0
const ALERT_TIME := 2.0
const GRAVITY := 600.0

enum State { PATROL, ALERT, CHASE, BANISHED }

@export var patrol_points: Array[Vector2] = []
@export var facing_right: bool = true

var state: State = State.PATROL
var current_patrol_index: int = 0
var alert_timer: float = 0.0
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var glow: PointLight2D = $Glow

func _ready() -> void:
	modulate = Color(0.2, 0.1, 0.3, 0.7)
	detection_area.body_entered.connect(_on_body_entered_detection)
	detection_area.body_exited.connect(_on_body_exited_detection)
	if patrol_points.is_empty():
		patrol_points = [global_position + Vector2(-60, 0), global_position + Vector2(60, 0)]

func _physics_process(delta: float) -> void:
	if state == State.BANISHED:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.PATROL:
			_patrol(delta)
		State.ALERT:
			_alert(delta)
		State.CHASE:
			_chase(delta)

	move_and_slide()

func _patrol(_delta: float) -> void:
	var target: Vector2 = patrol_points[current_patrol_index]
	var direction := sign(target.x - global_position.x)
	velocity.x = direction * PATROL_SPEED
	facing_right = direction > 0
	sprite.flip_h = not facing_right

	if abs(global_position.x - target.x) < 5.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _alert(delta: float) -> void:
	velocity.x = 0
	alert_timer -= delta
	if alert_timer <= 0:
		if player_ref and _can_see_player():
			state = State.CHASE
		else:
			state = State.PATROL

func _chase(_delta: float) -> void:
	if not player_ref:
		state = State.PATROL
		return
	if player_ref.is_hiding:
		state = State.PATROL
		player_ref = null
		return
	var direction := sign(player_ref.global_position.x - global_position.x)
	velocity.x = direction * CHASE_SPEED
	facing_right = direction > 0
	sprite.flip_h = not facing_right

func _on_body_entered_detection(body: Node2D) -> void:
	if body is CharacterBody2D and body.has_method("_start_crank"):
		if body.is_hiding:
			return
		player_ref = body
		state = State.ALERT
		alert_timer = ALERT_TIME

func _on_body_exited_detection(body: Node2D) -> void:
	if body == player_ref and state == State.ALERT:
		state = State.PATROL

func _can_see_player() -> bool:
	if not player_ref:
		return false
	return not player_ref.is_hiding

func banish() -> void:
	state = State.BANISHED
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()

func catch_player() -> void:
	if player_ref and state == State.CHASE:
		var distance := global_position.distance_to(player_ref.global_position)
		if distance < 20.0:
			GameManager.teleport_to_random_room()
```

- [ ] **Step 2: Create spirit guardian scene in editor**

Create `scenes/characters/spirit_guardian.tscn`:

1. Root: **CharacterBody2D** (rename to "SpiritGuardian")
2. Add: **CollisionShape2D** — RectangleShape2D (24x48)
3. Add: **AnimatedSprite2D** — use spirit_placeholder.png, modulate dark purple
4. Add: **Area2D** (rename to "DetectionArea")
   - Child of DetectionArea: **CollisionShape2D** — CircleShape2D radius 80
   - Set Area2D collision layer: 0, mask: 1
5. Add: **PointLight2D** (rename to "Glow") — color: dark purple (#2A0040), energy: 0.3, texture_scale: 1.0
6. Attach script: `res://scripts/characters/spirit_guardian.gd`
7. Set collision layer: 1, mask: 1

- [ ] **Step 3: Add catch check in _physics_process**

Add to end of `_chase` method:
```gdscript
	var distance := global_position.distance_to(player_ref.global_position)
	if distance < 25.0:
		_initiate_qte()

func _initiate_qte() -> void:
	state = State.BANISHED
	velocity.x = 0
	if player_ref and player_ref.has_node("Flashlight"):
		var fl = player_ref.get_node("Flashlight")
		fl.start_qte()
		var qte_overlay = get_tree().get_first_node_in_group("qte_overlay")
		if qte_overlay:
			qte_overlay.start_qte(fl)
		fl.qte_success.connect(func(): banish(), CONNECT_ONE_SHOT)
		fl.qte_failure.connect(func(): GameManager.teleport_to_random_room(), CONNECT_ONE_SHOT)
```

- [ ] **Step 4: Place guardian in a test room**

In `room_bedroom.tscn`, instance `scenes/characters/spirit_guardian.tscn`:
- Position at (350, 296)
- Set patrol_points to [(250, 296), (450, 296)]

- [ ] **Step 5: Run and verify**

Run F5:
- Guardian patrols between two points
- Walk into detection range → guardian stops (alert state)
- Stay 2 seconds → guardian chases
- Guardian reaches player → QTE starts, "[E] [E] [E]" prompt, progress bar
- Mash E fast → bar fills → flash → guardian disappears
- Fail QTE → screen fades, teleport to random room
- While chased, go to hideable + press Q → guardian loses track

- [ ] **Step 6: Commit**

```bash
git add scripts/characters/spirit_guardian.gd scenes/characters/spirit_guardian.tscn
git commit -m "feat: spirit guardian with patrol, chase, QTE encounter, and hiding evasion"
```

---

## Task 9: Laika Spirit Dog

**Files:**
- Create: `scripts/characters/laika.gd`
- Create: `scenes/characters/laika.tscn` (via editor)

### Steps

- [ ] **Step 1: Create laika script**

`scripts/characters/laika.gd`:
```gdscript
extends CharacterBody2D

const MOVE_SPEED := 70.0
const FOLLOW_DISTANCE := 60.0
const HINT_DISTANCE := 20.0
const IDLE_HINT_TIMEOUT := 60.0
const GRAVITY := 600.0

enum State { IDLE, FOLLOW_PLAYER, LEAD_TO, SIT_AT, DISAPPEAR }
enum Hint { NONE, SIT_AT_DOOR, GROWL, SCRATCH, HAPPY }

@export var hint_target: Node2D = null
@export var auto_appear: bool = true

var state: State = State.IDLE
var current_hint: Hint = Hint.NONE
var player_ref: CharacterBody2D = null
var lead_target: Vector2 = Vector2.ZERO
var idle_timer: float = 0.0
var is_visible_spirit: bool = true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var glow: PointLight2D = $Glow

func _ready() -> void:
	modulate = Color(1, 1, 1, 0.7)
	_find_player()
	if not auto_appear:
		disappear()

func _find_player() -> void:
	await get_tree().process_frame
	player_ref = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not is_visible_spirit:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match state:
		State.FOLLOW_PLAYER:
			_follow_player(delta)
		State.LEAD_TO:
			_lead_to_target(delta)
		State.SIT_AT:
			velocity.x = 0
		State.IDLE:
			velocity.x = 0
			_check_idle_hint(delta)

	move_and_slide()
	_update_animation()
	_bob_glow(delta)

func _follow_player(_delta: float) -> void:
	if not player_ref:
		return
	var dist := global_position.x - player_ref.global_position.x
	if abs(dist) > FOLLOW_DISTANCE:
		var dir := -sign(dist)
		velocity.x = dir * MOVE_SPEED
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0

func _lead_to_target(_delta: float) -> void:
	var dist := lead_target.x - global_position.x
	if abs(dist) > HINT_DISTANCE:
		var dir := sign(dist)
		velocity.x = dir * MOVE_SPEED
		sprite.flip_h = dir < 0
	else:
		velocity.x = 0
		state = State.SIT_AT
		current_hint = Hint.SIT_AT_DOOR

func _check_idle_hint(delta: float) -> void:
	idle_timer += delta
	if idle_timer >= IDLE_HINT_TIMEOUT and hint_target:
		lead_to(hint_target.global_position)
		idle_timer = 0.0

func _update_animation() -> void:
	if abs(velocity.x) > 1.0:
		sprite.play("walk")
	else:
		match current_hint:
			Hint.GROWL:
				sprite.play("growl")
			Hint.SIT_AT_DOOR:
				sprite.play("sit")
			_:
				sprite.play("idle")

func _bob_glow(delta: float) -> void:
	glow.energy = 0.4 + sin(Time.get_ticks_msec() * 0.003) * 0.1

func appear() -> void:
	is_visible_spirit = true
	visible = true
	var tween := create_tween()
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 0.7, 0.8)

func disappear() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	await tween.finished
	is_visible_spirit = false
	visible = false

func lead_to(target_pos: Vector2) -> void:
	state = State.LEAD_TO
	lead_target = target_pos

func follow_player() -> void:
	state = State.FOLLOW_PLAYER
	current_hint = Hint.NONE

func sit_at(pos: Vector2) -> void:
	global_position = pos
	state = State.SIT_AT
	current_hint = Hint.SIT_AT_DOOR

func growl() -> void:
	current_hint = Hint.GROWL

func happy() -> void:
	current_hint = Hint.HAPPY

func reset_hint() -> void:
	current_hint = Hint.NONE
	idle_timer = 0.0
```

- [ ] **Step 2: Create laika scene in editor**

Create `scenes/characters/laika.tscn`:

1. Root: **CharacterBody2D** (rename to "Laika")
2. Add: **CollisionShape2D** — RectangleShape2D (20x16)
3. Add: **AnimatedSprite2D** — use laika_placeholder.png (24x20 tan rectangle), create animations: idle (1 frame), walk (1 frame), sit (1 frame), growl (1 frame)
4. Add: **PointLight2D** (rename to "Glow") — color: warm white (#FFF8E8), energy: 0.4, texture_scale: 0.8
5. Attach script: `res://scripts/characters/laika.gd`
6. Set collision layer: 0, mask: 1 (doesn't block anything, just affected by gravity)
7. Add Laika to group "laika"

- [ ] **Step 3: Add player to group**

In `scenes/player/player.tscn`, add the Player node to group "player" (Node → Groups → add "player").

- [ ] **Step 4: Place laika in main hall**

In `room_main_hall.tscn`:
1. Instance `scenes/characters/laika.tscn` — position at (200, 308)
2. Set auto_appear = true
3. Optionally set hint_target to one of the doors

- [ ] **Step 5: Run and verify**

Run F5:
- Laika appears in main hall with soft glow, semi-transparent
- Walk away from laika → she follows, keeping distance
- Stand still 60 seconds → laika starts moving toward hint target
- Laika has gentle bobbing glow effect

- [ ] **Step 6: Commit**

```bash
git add scripts/characters/laika.gd scenes/characters/laika.tscn
git commit -m "feat: spirit laika guide with follow, lead, sit, and hint behaviors"
```

---

## Task 10: Audio Manager + Ambient Sound

**Files:**
- Modify: `scripts/autoload/audio_manager.gd`

### Steps

- [ ] **Step 1: Expand audio manager**

Replace `scripts/autoload/audio_manager.gd`:
```gdscript
extends Node

var ambient_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var breathing_player: AudioStreamPlayer

const MAX_SFX_PLAYERS := 4
const RANDOM_SCARE_CHANCE := 0.1

func _ready() -> void:
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = -6.0
	add_child(ambient_player)

	breathing_player = AudioStreamPlayer.new()
	breathing_player.bus = "Master"
	breathing_player.volume_db = -20.0
	add_child(breathing_player)

	for i in MAX_SFX_PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return

func play_ambient(stream: AudioStream, fade_in: float = 1.0) -> void:
	if ambient_player.playing:
		var tween := create_tween()
		tween.tween_property(ambient_player, "volume_db", -40.0, fade_in * 0.5)
		await tween.finished
	ambient_player.stream = stream
	ambient_player.volume_db = -40.0
	ambient_player.play()
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", -6.0, fade_in)

func stop_ambient(fade_out: float = 1.0) -> void:
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", -40.0, fade_out)
	await tween.finished
	ambient_player.stop()

func set_breathing_intensity(intensity: float) -> void:
	breathing_player.volume_db = lerpf(-40.0, -8.0, clampf(intensity, 0.0, 1.0))

func maybe_play_random_scare(sounds: Array[AudioStream]) -> void:
	if randf() < RANDOM_SCARE_CHANCE and not sounds.is_empty():
		var sound: AudioStream = sounds[randi() % sounds.size()]
		play_sfx(sound, -12.0)
```

- [ ] **Step 2: Run and verify**

Run F5:
- No errors on startup
- AudioManager is accessible from any script via `AudioManager.play_sfx()`
- (Actual audio files added later when content is assembled)

- [ ] **Step 3: Commit**

```bash
git add scripts/autoload/audio_manager.gd
git commit -m "feat: audio manager with ambient fading, multi-channel SFX, and breathing intensity"
```

---

## Task 11: Build All 6 Rooms

**Files:**
- Create/modify: all 6 room scenes in `scenes/rooms/`

### Steps

- [ ] **Step 1: Create room template structure**

Every room follows this pattern:
```
Node2D (root)
├── ColorRect (Background)           — full viewport, dark color unique per room
├── ColorRect (FloorVisual)          — bottom strip, wood texture color
├── StaticBody2D (Floor)
│   └── CollisionShape2D             — WorldBoundaryShape2D at y=320
├── StaticBody2D (WallLeft)
│   └── CollisionShape2D             — RectangleShape2D at x=0
├── StaticBody2D (WallRight)
│   └── CollisionShape2D             — RectangleShape2D at x=640
├── Marker2D (SpawnPoint)            — where player appears
├── [Door instances]
├── [Interactable instances]
├── [Optional: Laika instance]
├── [Optional: SpiritGuardian instance]
└── HUD instance
```

- [ ] **Step 2: Create room_entrance.tscn**

- Background: #0D0805 (very dark, cold)
- Floor at y=320
- Walls at x=0 and x=640
- SpawnPoint at (100, 300)
- Door "door_inside" at (550, 296) → leads to main_hall
- Door "door_outside" at (50, 296) → locked, message: "Дверь не поддаётся... Снаружи воет метель."
- Examinable: window at (300, 250) → "За окном — стена метели. Ничего не видно."

- [ ] **Step 3: Create room_main_hall.tscn**

- Background: #1A0F0A (warm dark brown)
- SpawnPoint at (100, 300)
- Door "door_entrance" at (50, 296) → entrance
- Door "door_left" at (250, 296) → bedroom
- Door "door_right" at (550, 296) → corridor
- Examinable: table at (320, 308) → "На столе остывшая еда. Кто-то готовил совсем недавно..."
- Examinable: fireplace at (400, 280) → "Огонь в печи ещё горит. Но дров рядом нет."
- Laika instance at (200, 308), auto_appear=true, hint_target=door_left

- [ ] **Step 4: Create room_bedroom.tscn**

- Background: #1A0D12 (cold purple-brown)
- SpawnPoint at (500, 300)
- Door "door_back" at (550, 296) → main_hall
- Hideable: wardrobe at (100, 280)
- Pickable: note at (250, 310) → item_id="note_shelf", pickup_text="Записка: 'Посмотри за иконой на полке.'"
- Examinable: shelf with movable icon at (350, 290) → triggers reveal of artifact_1
- Pickable: bone amulet at (355, 295) → item_id="artifact_bone_amulet", pickup_text="Костяной амулет. От него исходит странное тепло." (initially hidden, revealed by examining shelf after reading note)

- [ ] **Step 5: Create room_corridor.tscn**

- Background: #0F0A0A (very dark, oppressive)
- SpawnPoint at (50, 300)
- Door "door_left" at (50, 296) → main_hall
- Door "door_right" at (550, 296) → storage
- Door "door_down" at (320, 296) → basement (locked, required_item="storage_key")
- Examinable: scratches on wall at (200, 270) → "Царапины на стене. Кто-то считал дни... Отметок больше сотни."
- Trigger: Aiyyna first appearance — scripted silhouette at far end

- [ ] **Step 6: Create room_storage.tscn**

- Background: #120D08 (dusty dark)
- SpawnPoint at (500, 300)
- Door "door_back" at (550, 296) → corridor
- Hideable: behind crates at (150, 300)
- SpiritGuardian: patrol_points [(200, 300), (450, 300)]
- Puzzle elements for artifact 2:
  - Examinable: symbols on wall at (100, 260) → "Символы на стене. Четыре фигуры: олень, ворон, медведь, рыба."
  - Usable: stone slots at (300, 300) → required sequence from note in corridor
- Pickable: shaman drum at (300, 280) → item_id="artifact_shaman_drum" (appears after puzzle solved)
- Pickable: storage_key at (450, 310) → item_id="storage_key", pickup_text="Ржавый ключ. Подойдёт к тяжёлой двери."

- [ ] **Step 7: Create room_basement.tscn**

- Background: #050203 (almost black)
- SpawnPoint at (320, 200) (enters from top — ladder/stairs feel)
- Door "door_up" at (320, 180) → corridor
- Two SpiritGuardians:
  - Guardian 1: patrol_points [(100, 300), (300, 300)]
  - Guardian 2: patrol_points [(350, 300), (550, 300)]
- Laika: auto_appear = false (she doesn't come here)
- Puzzle: 3 mirror fragments
  - Pickable: fragment_1 at (80, 310) → item_id="mirror_1"
  - Pickable: fragment_2 at (400, 310) → item_id="mirror_2"
  - Pickable: fragment_3 at (580, 310) → item_id="mirror_3"
  - Usable: mirror frame at (300, 260) → needs all 3 fragments → reveals artifact_3
- Pickable: earring at (300, 265) → item_id="artifact_earring" (appears after mirror assembled)
- Flashlight drain rate increased (set via room script)

- [ ] **Step 8: Ensure each room has HUD**

Instance `scenes/ui/hud.tscn` as child in every room scene.

- [ ] **Step 9: Add SpawnPoint logic to GameManager**

Add to `scripts/autoload/game_manager.gd`:
```gdscript
var spawn_door_id: String = ""

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
	# Find the door the player came from and place them there
	for node in get_tree().get_nodes_in_group("doors"):
		if node is Interactable and node.has_method("get_door_id"):
			pass
	# Fallback: use SpawnPoint marker
	var spawn := get_tree().current_scene.get_node_or_null("SpawnPoint")
	if spawn:
		player.global_position = spawn.global_position
```

- [ ] **Step 10: Run and verify**

Run F5:
- Navigate all 6 rooms via doors
- Each room has distinct color/atmosphere
- Doors connect correctly per room_graph.json
- Locked doors show messages
- Guardian patrols in storage and basement
- Laika appears in main hall, absent in basement

- [ ] **Step 11: Commit**

```bash
git add scenes/rooms/ scripts/autoload/game_manager.gd
git commit -m "feat: all 6 rooms with doors, interactables, enemies, and navigation"
```

---

## Task 12: Puzzle Logic + Artifact Collection

**Files:**
- Create: `scripts/rooms/room_bedroom_logic.gd`
- Create: `scripts/rooms/room_storage_logic.gd`
- Create: `scripts/rooms/room_basement_logic.gd`
- Modify: `scripts/autoload/game_manager.gd` — distortion triggers

### Steps

- [ ] **Step 1: Create bedroom puzzle script**

`scripts/rooms/room_bedroom_logic.gd`:
```gdscript
extends Node2D

@onready var note: Node = $NotePickable
@onready var shelf: Node = $ShelfExaminable
@onready var amulet: Node = $AmuletPickable

var note_read: bool = false

func _ready() -> void:
	if Inventory.has_item("artifact_bone_amulet"):
		if amulet:
			amulet.queue_free()
		return
	amulet.visible = false
	amulet.set_process(false)

func _on_note_picked_up() -> void:
	note_read = true

func _on_shelf_examined() -> void:
	if note_read or Inventory.has_item("note_shelf"):
		amulet.visible = true
		amulet.set_process(true)
		DialogueManager.show_text("", "За иконой что-то спрятано...")

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("bone_amulet")
	_trigger_flashback_1()

func _trigger_flashback_1() -> void:
	var fl := get_tree().get_first_node_in_group("player").get_node("Flashlight")
	if fl:
		fl.scripted_off()
	# Warm palette shift
	var bg: ColorRect = $Background
	var tween := create_tween()
	tween.tween_property(bg, "color", Color("#3D2B1A"), 1.0)
	await get_tree().create_timer(3.0).timeout
	DialogueManager.show_text("", "Видение: девушка входит в балаган, спасаясь от метели. Она улыбается — здесь тепло...")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", Color("#1A0D12"), 1.0)
	if fl:
		fl.scripted_on()
```

- [ ] **Step 2: Create storage puzzle script**

`scripts/rooms/room_storage_logic.gd`:
```gdscript
extends Node2D

@export var correct_order: Array[String] = ["deer", "raven", "bear", "fish"]

var placed_stones: Array[String] = []
var puzzle_solved: bool = false

@onready var drum: Node = $DrumPickable

func _ready() -> void:
	if Inventory.has_item("artifact_shaman_drum"):
		if drum:
			drum.queue_free()
		return
	drum.visible = false

func place_stone(symbol: String) -> void:
	placed_stones.append(symbol)
	if placed_stones.size() == correct_order.size():
		_check_solution()

func _check_solution() -> void:
	if placed_stones == correct_order:
		puzzle_solved = true
		drum.visible = true
		DialogueManager.show_text("", "Камни засветились. За ними открылся тайник...")
	else:
		placed_stones.clear()
		DialogueManager.show_text("", "Ничего не произошло. Нужно попробовать другой порядок.")

func _on_drum_picked_up() -> void:
	GameManager.collect_artifact("shaman_drum")
	_trigger_flashback_2()

func _trigger_flashback_2() -> void:
	var fl := get_tree().get_first_node_in_group("player").get_node("Flashlight")
	if fl:
		fl.scripted_off()
	var bg: ColorRect = $Background
	var tween := create_tween()
	tween.tween_property(bg, "color", Color("#3D2B1A"), 1.0)
	await get_tree().create_timer(3.0).timeout
	DialogueManager.show_text("", "Видение: Айыына сидит у огня с бубном. Она поёт, но что-то идёт не так — тени на стенах начинают двигаться...")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", Color("#120D08"), 1.0)
	if fl:
		fl.scripted_on()
```

- [ ] **Step 3: Create basement puzzle script**

`scripts/rooms/room_basement_logic.gd`:
```gdscript
extends Node2D

var fragments_placed: int = 0
@onready var earring: Node = $EarringPickable
@onready var flashlight_drain_multiplier: float = 2.0

func _ready() -> void:
	if Inventory.has_item("artifact_earring"):
		if earring:
			earring.queue_free()
		return
	earring.visible = false
	# Increase flashlight drain in basement
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_node("Flashlight"):
		var fl = player.get_node("Flashlight")
		fl.set_meta("drain_multiplier", flashlight_drain_multiplier)

func place_fragment() -> void:
	fragments_placed += 1
	if fragments_placed >= 3:
		_mirror_complete()

func _mirror_complete() -> void:
	DialogueManager.show_text("", "Зеркало собрано. В отражении видна стена... но за ней — проход.")
	await DialogueManager.dialogue_finished
	earring.visible = true

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_trigger_flashback_3()

func _trigger_flashback_3() -> void:
	var fl := get_tree().get_first_node_in_group("player").get_node("Flashlight")
	if fl:
		fl.scripted_off()
	var bg: ColorRect = $Background
	var tween := create_tween()
	tween.tween_property(bg, "color", Color("#3D2B1A"), 1.0)
	await get_tree().create_timer(3.0).timeout
	DialogueManager.show_text("", "Видение: Айыына кричит. Тени обступают её. Она пытается бежать, но двери нет. Стены смыкаются...")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Видение: тишина. Серьга падает на пол. Девушки больше нет.")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", Color("#050203"), 1.0)
	if fl:
		fl.scripted_on()
```

- [ ] **Step 4: Add room distortion triggers to GameManager**

Add to `scripts/autoload/game_manager.gd`:
```gdscript
func _on_artifact_collected(artifact_id: String) -> void:
	match artifact_id:
		"bone_amulet":
			# Corridor right door now loops back to main hall
			mutate_door("corridor", "door_right", "main_hall")
		"shaman_drum":
			# Entrance inside door leads to corridor instead of main hall
			mutate_door("entrance", "door_inside", "corridor")
			# Bedroom back door leads to storage
			mutate_door("bedroom", "door_back", "storage")
		"earring":
			# All doors lead correctly — unlock finale
			reset_room_graph()
			# Unlock the outside door
			pass

func _ready() -> void:
	_load_room_graph()
	artifact_collected.connect(_on_artifact_collected)
```

- [ ] **Step 5: Run and verify**

Run F5:
- Bedroom: read note → examine shelf → amulet appears → pick up → flashback plays (warm palette)
- After amulet: corridor doors are remapped — disorienting
- Storage: place stones in order → drum appears → pick up → flashback
- Basement: find 3 fragments → place in mirror → earring appears → flashback (darkest)
- Room connections change after each artifact

- [ ] **Step 6: Commit**

```bash
git add scripts/rooms/ scripts/autoload/game_manager.gd
git commit -m "feat: 3 artifact puzzles with flashbacks and room distortion triggers"
```

---

## Task 13: Finale Sequence + Credits

**Files:**
- Create: `scripts/rooms/finale.gd`
- Create: `scenes/rooms/room_finale.tscn` (via editor)
- Create: `scenes/ui/credits.tscn` (via editor)
- Create: `scripts/ui/credits.gd`

### Steps

- [ ] **Step 1: Create finale script**

`scripts/rooms/finale.gd`:
```gdscript
extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var laika: CharacterBody2D = $Laika
@onready var bg: ColorRect = $Background

var phase: int = 0

func _ready() -> void:
	if GameManager.artifacts_collected.size() < 3:
		# Not ready for finale, redirect
		GameManager.current_room = "main_hall"
		get_tree().change_scene_to_file("res://scenes/rooms/room_main_hall.tscn")
		return
	_start_finale()

func _start_finale() -> void:
	# Phase 1: Ritual complete, Aiyyna freed
	var fl = player.get_node("Flashlight")
	fl.scripted_off()

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Три артефакта на алтаре. Воздух вибрирует.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Силуэт Айыыны становится ярким, тёплым. Впервые — она улыбается.")
	await DialogueManager.dialogue_finished

	var tween := create_tween()
	tween.tween_property(bg, "color", Color("#2A1A0A"), 2.0)
	await tween.finished

	DialogueManager.show_text("Айыына", "...Спасибо.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(2.0).timeout
	DialogueManager.show_text("", "Свет рассеивается. Айыына исчезает. Стены перестают дрожать.")
	await DialogueManager.dialogue_finished

	fl.scripted_on()

	# Phase 2: Walk to exit
	DialogueManager.show_text("", "Дверь наружу открыта. Наконец-то.")
	await DialogueManager.dialogue_finished

	# Phase 3: Laika farewell
	await get_tree().create_timer(1.0).timeout
	laika.follow_player()
	DialogueManager.show_text("", "Лайка идёт рядом. Впервые — не впереди, а рядом.")
	await DialogueManager.dialogue_finished

	# Player walks toward door, laika stops
	await get_tree().create_timer(2.0).timeout
	laika.velocity = Vector2.ZERO
	laika.state = laika.State.SIT_AT

	DialogueManager.show_text("", "На пороге оборачиваюсь. Она сидит. Не идёт за мной.")
	await DialogueManager.dialogue_finished

	DialogueManager.show_text("", "Тяну руку... Рука проходит сквозь.")
	await DialogueManager.dialogue_finished

	# Laika dissolves
	var laika_tween := create_tween()
	laika.glow.energy = 1.0
	laika_tween.tween_property(laika, "modulate:a", 0.0, 3.0)
	laika_tween.parallel().tween_property(laika.glow, "energy", 2.0, 1.5)
	laika_tween.parallel().tween_property(laika.glow, "energy", 0.0, 1.5).set_delay(1.5)

	await get_tree().create_timer(1.5).timeout
	DialogueManager.show_text("", "Тихий скулёж. Она светится — так же, как Айыына.")
	await DialogueManager.dialogue_finished

	await laika_tween.finished

	await get_tree().create_timer(2.0).timeout
	DialogueManager.show_text("", "Тишина. Я один на пороге. Метель стихла.")
	await DialogueManager.dialogue_finished

	# Phase 4: Post-credits
	await get_tree().create_timer(2.0).timeout
	_post_credits()

func _post_credits() -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Машина заводится. Связь появилась.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "На заднем сиденье — костяной амулет. И рядом... маленький клок шерсти.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
```

- [ ] **Step 2: Create credits script**

`scripts/ui/credits.gd`:
```gdscript
extends Control

@onready var label: RichTextLabel = $RichTextLabel

func _ready() -> void:
	label.text = ""
	_play_credits()

func _play_credits() -> void:
	await get_tree().create_timer(2.0).timeout
	label.text = "[center]В память о верных друзьях,\nкоторые остаются рядом.[/center]"
	await get_tree().create_timer(4.0).timeout
	label.text = "[center]Они ждут тебя.\n\n[Название приюта][/center]"
	await get_tree().create_timer(5.0).timeout
	label.text = "[center]БАЛАГАН\n\nСпасибо за игру.[/center]"
	await get_tree().create_timer(5.0).timeout
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		get_tree().quit()
```

- [ ] **Step 3: Create credits scene in editor**

Create `scenes/ui/credits.tscn`:

1. Root: **Control** (rename to "Credits") — anchors: full rect
2. Add: **ColorRect** — full rect, color: black
3. Add: **RichTextLabel** — anchors: center, size: (400, 200), bbcode_enabled: true, horizontal_alignment: center, font_size: 16, modulate: warm white
4. Attach script: `res://scripts/ui/credits.gd`

- [ ] **Step 4: Create finale room scene in editor**

Create `scenes/rooms/room_finale.tscn`:
1. Root: **Node2D** — dark background
2. Instance Player + Laika
3. Simple environment: altar, door, dark room
4. Attach `scripts/rooms/finale.gd`

- [ ] **Step 5: Connect finale trigger in GameManager**

In `_on_artifact_collected` after "earring" case:
```gdscript
		"earring":
			reset_room_graph()
			# After returning to main hall, entrance door leads to finale
			mutate_door("entrance", "door_outside", "finale")
			# Add finale to graph
			room_graph["rooms"]["finale"] = {
				"scene": "res://scenes/rooms/room_finale.tscn",
				"doors": {}
			}
```

- [ ] **Step 6: Run and verify full playthrough**

Run F5, complete all 3 artifacts:
- After collecting earring, navigate to entrance
- Outside door now unlocked → leads to finale scene
- Finale plays through all phases: ritual, Aiyyna, Laika farewell, car, credits
- Credits screen shows shelter dedication
- Any key → game quits

- [ ] **Step 7: Commit**

```bash
git add scripts/rooms/finale.gd scripts/ui/credits.gd scenes/rooms/room_finale.tscn scenes/ui/credits.tscn scripts/autoload/game_manager.gd
git commit -m "feat: finale sequence with Laika farewell twist, post-credits, and shelter dedication"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Sec 1: Project structure — Task 1
- [x] Sec 2: Player + controls — Task 1
- [x] Sec 3: Room system + distortion — Tasks 2, 11, 12
- [x] Sec 4: Inventory + interactables — Tasks 3, 4
- [x] Sec 5: Spirits (Laika, Aiyyna, guardians) — Tasks 8, 9, 12
- [x] Sec 6: Flashlight — Task 6
- [x] Sec 7: Stealth + hiding — Tasks 7, 8
- [x] Sec 8: Puzzles + artifacts — Task 12
- [x] Sec 9: Audio — Task 10
- [x] Sec 10: Finale + twist — Task 13

**Placeholder scan:** No TBD, TODO, or "implement later" found.

**Type consistency:**
- `Interactable.Type` enum used consistently across door.gd, pickable.gd, examinable.gd, usable.gd, hideable.gd
- `GameManager` methods (change_room, collect_artifact, mutate_door, teleport_to_random_room) referenced consistently
- `Inventory` methods (add_item, remove_item, has_item, selected_item) match across all scripts
- `DialogueManager` methods (show_text, advance, is_active) consistent throughout
- Flashlight methods (scripted_off, scripted_on, start_qte, crank, stop_crank) match between flashlight.gd and all callers
- Laika states and methods (appear, disappear, follow_player, lead_to, sit_at, growl) consistent
