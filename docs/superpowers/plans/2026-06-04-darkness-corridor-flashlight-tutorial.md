# Darkness Corridor + Flashlight Tutorial — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teach the player to boost the flashlight in the forest via the сэргэ amulet, then gate the loop corridor path with two darkness corridors that the player must boost through — getting caught sends them 2 rooms back.

**Architecture:** Three independent subsystems wired together via `room_graph.json`. (1) Forest tutorial: modify existing `ShamanAmulet` examined handler to check flashlight boost state. (2) Two new corridor scenes `room_corridor_dark.tscn` use a shared script `room_corridor_dark_logic.gd` that spawns a `Polygon2D` darkness wall moving at fixed speed; player boost dispels it instantly; catching the player triggers `GameManager.change_room_direct()` to jump 2 rooms back. (3) `room_graph.json` inserts `dark_c1` (between `entry_c2` and `closet`) and `dark_c2` (between `entry_c3` and `entry_c4`).

**Tech Stack:** Godot 4.3, GDScript, existing SubtitleManager / DialogueManager autoloads, existing `Flashlight` node on Player.

---

## File Map

| Action  | Path |
|---------|------|
| Modify  | `scripts/rooms/room_forest_logic.gd` |
| Modify  | `scripts/autoload/game_manager.gd` |
| Create  | `scripts/rooms/room_corridor_dark_logic.gd` |
| Create  | `scenes/rooms/room_corridor_dark.tscn` |
| Modify  | `data/room_graph.json` |

---

## Task 1 — Flashlight tutorial on сэргэ in the forest

`ShamanAmulet` (examinable at position 2400, 289) is already in `room_forest.tscn`. Currently examining it always shows the full amulet text. Change it so:
- Without boost → "can't see" + hint `[F] — усилить свет`
- With boost → original ghost flash + full amulet text (marks tutorial done)

**Files:**
- Modify: `scripts/rooms/room_forest_logic.gd`

---

- [ ] **Step 1.1 — Add tutorial flag and rewrite `_on_murder_site_examined`**

In `scripts/rooms/room_forest_logic.gd`, add `_serge_tutorial_done: bool = false` after the existing flags, and replace `_on_murder_site_examined`:

```gdscript
var _laika_appeared: bool = false
var _chapter_started: bool = false
var _silhouette_triggered: bool = false
var _balagan_triggered: bool = false
var _ghost_shown: bool = false
var _serge_tutorial_done: bool = false
```

Replace the full `_on_murder_site_examined` function:

```gdscript
func _on_murder_site_examined() -> void:
	var player := get_node_or_null("Player")
	var flashlight = player.get_node_or_null("Flashlight") if player else null
	var boosting: bool = flashlight != null and flashlight.is_boost_active

	if not boosting and not _serge_tutorial_done:
		DialogueManager.show_text("", "На сэргэ что-то висит. Не могу рассмотреть — слишком темно. Надо посветить поярче.")
		await DialogueManager.dialogue_finished
		SubtitleManager.show_subtitle("[F] — усилить свет", SubtitleManager.Pos.BOTTOM_CENTER)
		return

	if not _serge_tutorial_done:
		_serge_tutorial_done = true
		if not _ghost_shown:
			_ghost_shown = true
			_flash_ghost_once()
		DialogueManager.show_text("", "Птичьи кости, нанизанные на истлевшую нить. Давно. Кора дерева вросла в узел — значит, висит годами.")
		await DialogueManager.dialogue_finished
		DialogueManager.show_text("", "Такое оставляют не как подношение. Как замок. Чтобы что-то не ушло с этого места.")
```

- [ ] **Step 1.2 — Verify logic**

Read `scripts/rooms/room_forest_logic.gd` lines 1-45 and confirm:
- `_serge_tutorial_done` declared with other flags
- `_on_murder_site_examined` checks `flashlight.is_boost_active`
- Without boost: shows "can't see" text + SubtitleManager hint
- With boost + first time: sets flag, flashes ghost, shows full text

- [ ] **Step 1.3 — Commit**

```
git add scripts/rooms/room_forest_logic.gd
git commit -m "feat: flashlight tutorial on serge — boost required to examine amulet"
```

---

## Task 2 — Add `change_room_direct` to GameManager

The darkness penalty needs to jump directly to a target room_id without going through door lookups. This function mirrors `change_room` but accepts a room_id directly.

**Files:**
- Modify: `scripts/autoload/game_manager.gd`

---

- [ ] **Step 2.1 — Add `change_room_direct` function**

In `scripts/autoload/game_manager.gd`, after the `change_room` function (around line 77), add:

```gdscript
func change_room_direct(room_id: String, spawn_door: String = "door_back") -> void:
	if is_transitioning:
		return
	var scene_path := get_room_scene(room_id)
	if scene_path.is_empty():
		return
	is_transitioning = true
	spawn_door_id = spawn_door
	_ensure_fade()
	await _screen_fade.fade_out(0.5)
	current_room = room_id
	transition_count += 1
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	_place_player_at_door()
	_ensure_fade()
	await _screen_fade.fade_in(0.5)
	is_transitioning = false
	room_changed.emit(room_id)
```

- [ ] **Step 2.2 — Verify**

Read the file and confirm `change_room_direct` is present after `change_room`, with the same fade/place pattern.

- [ ] **Step 2.3 — Commit**

```
git add scripts/autoload/game_manager.gd
git commit -m "feat: GameManager.change_room_direct for direct room jump by id"
```

---

## Task 3 — Create darkness corridor logic script

This script drives the darkness mechanic. It is used by both `dark_c1` and `dark_c2` corridor rooms (same scene, different room_id in the graph).

**Files:**
- Create: `scripts/rooms/room_corridor_dark_logic.gd`

---

- [ ] **Step 3.1 — Create the script**

Create `scripts/rooms/room_corridor_dark_logic.gd` with this full content:

```gdscript
extends Node2D

const DARKNESS_SPEED   := 28.0   # pixels per second, fixed
const DARKNESS_START_X := 1700.0 # just off the right edge
const START_DELAY      := 2.5    # seconds before darkness begins moving
const ROOM_WIDTH       := 1600.0
const SHAKE_PROXIMITY  := 250.0  # px — camera starts shaking within this distance

var _darkness: Polygon2D
var _darkness_x: float = DARKNESS_START_X
var _active: bool = false
var _defeated: bool = false
var _penalty_done: bool = false
var _shake_time: float = 0.0

func _ready() -> void:
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left  = 0
			cam.limit_right = int(ROOM_WIDTH)

	_build_darkness()

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	_add_back_zone()

	get_tree().create_timer(START_DELAY).timeout.connect(func(): _active = true)

func _build_darkness() -> void:
	_darkness = Polygon2D.new()
	_darkness.polygon = PackedVector2Array([
		Vector2(0,    -60),
		Vector2(2000, -60),
		Vector2(2000,  420),
		Vector2(0,     420),
	])
	_darkness.color   = Color(0.0, 0.0, 0.02, 0.97)
	_darkness.z_index = 50
	_darkness.position.x = _darkness_x
	add_child(_darkness)

func _process(delta: float) -> void:
	if not _active or _defeated or _penalty_done:
		return

	_darkness_x         -= DARKNESS_SPEED * delta
	_darkness.position.x = _darkness_x

	var player := get_node_or_null("Player")
	if not player:
		return

	var flashlight = player.get_node_or_null("Flashlight")
	if flashlight and flashlight.is_boost_active:
		_dispel_darkness(player)
		return

	var dist: float = _darkness_x - player.global_position.x
	if dist < SHAKE_PROXIMITY:
		_shake_time += delta * 18.0
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.offset = Vector2(
				sin(_shake_time)        * lerp(0.0, 4.0, 1.0 - dist / SHAKE_PROXIMITY),
				sin(_shake_time * 0.7)  * lerp(0.0, 3.0, 1.0 - dist / SHAKE_PROXIMITY)
			)

	if dist <= 0.0:
		_trigger_penalty(player)

func _dispel_darkness(player: Node) -> void:
	_defeated = true
	_active   = false
	_reset_camera(player)
	var tween := create_tween()
	tween.tween_property(_darkness, "position:x", DARKNESS_START_X, 1.2)

func _trigger_penalty(player: Node) -> void:
	_penalty_done = true
	_active       = false
	_reset_camera(player)
	var two_back := _room_two_back()
	if two_back.is_empty():
		GameManager.change_room("door_back")
	else:
		GameManager.change_room_direct(two_back, "door_back")

func _room_two_back() -> String:
	var r1 := GameManager.get_door_target(GameManager.current_room, "door_back")
	if r1.is_empty():
		return ""
	return GameManager.get_door_target(r1, "door_back")

func _reset_camera(player: Node) -> void:
	var cam: Camera2D = player.get_node_or_null("Camera2D")
	if cam:
		var tween := create_tween()
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.3)

func _add_back_zone() -> void:
	var area  := Area2D.new()
	area.name  = "BackZone"
	area.collision_layer = 0
	area.collision_mask  = 1
	var shape := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size          = Vector2(40, 400)
	shape.position     = Vector2(0, 180)
	shape.shape        = rect
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			GameManager.change_room("door_back")
	)

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 3.2 — Verify file exists and has no obvious syntax errors**

Read `scripts/rooms/room_corridor_dark_logic.gd` lines 1-20 and confirm the file was created with the correct header.

- [ ] **Step 3.3 — Commit**

```
git add scripts/rooms/room_corridor_dark_logic.gd
git commit -m "feat: darkness corridor logic — creeping darkness, boost to dispel, 2-back penalty"
```

---

## Task 4 — Create darkness corridor scene

The scene is structurally identical to `room_corridor.tscn` (1600×360, same assets) but references the new dark logic script and has no Laika/Note nodes.

**Files:**
- Create: `scenes/rooms/room_corridor_dark.tscn`

---

- [ ] **Step 4.1 — Create the scene file**

Create `scenes/rooms/room_corridor_dark.tscn` with this exact content:

```
[gd_scene format=3 uid="uid://room_corridor_dark1"]

[ext_resource type="Script" path="res://scripts/rooms/room_corridor_dark_logic.gd" id="1_dark"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3_hud"]
[ext_resource type="Texture2D" path="res://assets/sprites/manor/floor_planks.png" id="manor_floor"]
[ext_resource type="Texture2D" path="res://assets/sprites/manor/wall_logs.png" id="manor_wall"]

[sub_resource type="WorldBoundaryShape2D" id="FloorShape"]

[sub_resource type="RectangleShape2D" id="LeftWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="RightWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="ExitShape"]
size = Vector2(60, 140)

[node name="RoomCorridorDark" type="Node2D"]
script = ExtResource("1_dark")

[node name="Background" type="TextureRect" parent="."]
offset_right = 1600.0
offset_bottom = 252.0
texture = ExtResource("manor_wall")
stretch_mode = 1

[node name="FloorVisual" type="TextureRect" parent="."]
offset_top = 252.0
offset_right = 1600.0
offset_bottom = 360.0
texture = ExtResource("manor_floor")
stretch_mode = 1

[node name="Player" parent="." instance=ExtResource("2_player")]
position = Vector2(80, 260)

[node name="HUD" parent="." instance=ExtResource("3_hud")]

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 262)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("FloorShape")

[node name="LeftWall" type="StaticBody2D" parent="."]
position = Vector2(-20, 350)

[node name="LeftWallShape" type="CollisionShape2D" parent="LeftWall"]
position = Vector2(0, -176)
shape = SubResource("LeftWallShape")

[node name="RightWall" type="StaticBody2D" parent="."]
position = Vector2(1600, 350)

[node name="RightWallShape" type="CollisionShape2D" parent="RightWall"]
position = Vector2(0, -176)
shape = SubResource("RightWallShape")

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 260)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(1600, 180)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ExitZone" type="Area2D" parent="."]
position = Vector2(1560, 235)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitZone"]
shape = SubResource("ExitShape")
```

- [ ] **Step 4.2 — Verify**

Read `scenes/rooms/room_corridor_dark.tscn` and confirm it has the script reference, player, floor, exit zone, and RoomRight/SpawnPoint markers.

- [ ] **Step 4.3 — Commit**

```
git add scenes/rooms/room_corridor_dark.tscn
git commit -m "feat: room_corridor_dark scene — darkness corridor with log wall assets"
```

---

## Task 5 — Wire dark corridors into room_graph.json

Insert `dark_c1` between `entry_c2 → closet` and `dark_c2` between `entry_c3 → entry_c4`. Update the existing `door_forward` targets for `entry_c2` and `entry_c3`.

**Files:**
- Modify: `data/room_graph.json`

---

- [ ] **Step 5.1 — Add dark_c1 and dark_c2 rooms, update forward links**

Replace the full content of `data/room_graph.json` with:

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
      "doors": { "door_forward": "dark_c1", "door_back": "entry_c1" }
    },
    "dark_c1": {
      "scene": "res://scenes/rooms/room_corridor_dark.tscn",
      "doors": { "door_forward": "closet", "door_back": "entry_c2" }
    },
    "entry_c3": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "dark_c2", "door_back": "closet" }
    },
    "dark_c2": {
      "scene": "res://scenes/rooms/room_corridor_dark.tscn",
      "doors": { "door_forward": "entry_c4", "door_back": "entry_c3" }
    },
    "entry_c4": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "main_hall", "door_back": "dark_c2" }
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

Key changes from original:
- `entry_c2.door_forward`: `"closet"` → `"dark_c1"`
- `entry_c3.door_forward`: `"entry_c4"` → `"dark_c2"`
- `entry_c4.door_back`: `"entry_c3"` → `"dark_c2"` (keeps graph consistent)
- Added `dark_c1` and `dark_c2` rooms

- [ ] **Step 5.2 — Verify**

Read `data/room_graph.json` and confirm:
- `entry_c2.door_forward` = `"dark_c1"` ✓
- `dark_c1.door_forward` = `"closet"`, `dark_c1.door_back` = `"entry_c2"` ✓
- `entry_c3.door_forward` = `"dark_c2"` ✓
- `dark_c2.door_forward` = `"entry_c4"`, `dark_c2.door_back` = `"entry_c3"` ✓

- [ ] **Step 5.3 — Verify 2-rooms-back math**

When player is caught in `dark_c1`:
- `_room_two_back()`: door_back of `dark_c1` = `entry_c2`, door_back of `entry_c2` = `entry_c1`
- Result: player sent to `entry_c1` ✓

When player is caught in `dark_c2`:
- `_room_two_back()`: door_back of `dark_c2` = `entry_c3`, door_back of `entry_c3` = `closet`
- Result: player sent to `closet` ✓

- [ ] **Step 5.4 — Commit**

```
git add data/room_graph.json
git commit -m "feat: insert dark_c1 and dark_c2 corridors into loop path"
```

---

## Self-Review

### Spec coverage

| Requirement | Task |
|---|---|
| Flashlight tutorial in forest on сэргэ | Task 1 |
| "Can't see" text → hint `[F]` | Task 1 |
| With boost → show full amulet text | Task 1 |
| Darkness moves at fixed speed from right | Task 3 `DARKNESS_SPEED = 28.0` |
| Flashlight boost completely dispels darkness | Task 3 `_dispel_darkness()` |
| Camera shake as darkness approaches | Task 3 `_shake_time` in `_process` |
| Caught by darkness → sent 2 rooms back | Task 3 `_trigger_penalty` + `_room_two_back()` |
| 1–2 new dark corridors added | Task 4+5 (dark_c1, dark_c2) |
| Player spawns on left side after loop | Already handled: `spawn_door_id="door_exit"` defaults to SpawnPoint x=80 in `_place_player_at_door()` — no additional code needed |

### Notes

- `dark_c1` 2-back penalty → `entry_c1`. Player walked: `entry_c1 → entry_c2 → dark_c1` (fail) → back to `entry_c1`. Must walk 3 rooms to reach dark_c1 again. ✓ Feels fair.
- `dark_c2` 2-back penalty → `closet`. Player walked: `closet → entry_c3 → dark_c2` (fail) → back to `closet`. Must walk 2 rooms to reach dark_c2 again. ✓
- `START_DELAY = 2.5s` gives normal-speed player time to pass (1600px ÷ 100px/s walk = 16s to cross, darkness takes 1700÷28 = 60s to reach x=0 — player always survives if walking). Darkness reaches player center (x≈800) after 32s. So darkness is only a threat if player stops for 30+ seconds, OR on very slow replays. **Adjust if needed**: lowering `START_DELAY` or raising `DARKNESS_SPEED` makes it more aggressive.
- Camera shake resets via `_reset_camera` tween — no permanent shake stuck on screen. ✓
