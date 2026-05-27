# Entry + Corridor Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `room_entry.tscn` and `room_corridor.tscn` to the highway/forest side-scroller format (Player in scene, Floor collision, camera limits, edge-zone transitions) and wire up the new `entry → corridor×2 → closet → corridor×2 → main_hall` route.

**Architecture:** Each room is a self-contained scene with a Player instance, HUD, Floor/Wall colliders, SpawnPoint/RoomRight/RoomBottom markers, and Area2D ExitZones at the edges. GameManager reads `RoomRight` and `RoomBottom` to auto-set camera limits after a room change. Logic scripts connect zones to `GameManager.change_room()` and set per-room narrative content.

**Tech Stack:** Godot 4.3, GDScript, `GameManager` autoload (persists `escape_attempts`, `current_room`), `SubtitleManager`, `DialogueManager`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `data/room_graph.json` | Modify | Route wiring: entry → entry_c1-c4 → main_hall |
| `scenes/rooms/room_entry.tscn` | Full rewrite | 1280px scene with Player, walls, two zones |
| `scripts/rooms/room_entry_logic.gd` | Full rewrite | Exit-loop mechanic, forward zone, clothes text |
| `scenes/rooms/room_corridor.tscn` | Full rewrite | 1600px scene with Player, walls, exit zone, Laika |
| `scripts/rooms/room_corridor_logic.gd` | Full rewrite | Per-room_id subtitles, window repeat, Laika on entry_c4 |

---

## Task 1: Update room_graph.json

**Files:**
- Modify: `data/room_graph.json`

- [ ] **Step 1: Replace the entry section and update closet**

Open `data/room_graph.json`. Replace the `"entry"` object and `"closet"` object, and add `"entry_c1"` through `"entry_c4"`. The rest of the file stays identical.

New content for the affected keys (merge into existing JSON — do not remove other keys like `"highway"`, `"forest"`, `"main_hall"`, `"corridor"`, etc.):

```json
"entry": {
  "scene": "res://scenes/rooms/room_entry.tscn",
  "doors": { "door_forward": "entry_c1", "door_exit": "entry" }
},
"entry_c1": {
  "scene": "res://scenes/rooms/room_corridor.tscn",
  "doors": { "door_forward": "entry_c2" }
},
"entry_c2": {
  "scene": "res://scenes/rooms/room_corridor.tscn",
  "doors": { "door_forward": "closet" }
},
"closet": {
  "scene": "res://scenes/rooms/room_closet.tscn",
  "doors": { "door_forward": "entry_c3" }
},
"entry_c3": {
  "scene": "res://scenes/rooms/room_corridor.tscn",
  "doors": { "door_forward": "entry_c4" }
},
"entry_c4": {
  "scene": "res://scenes/rooms/room_corridor.tscn",
  "doors": { "door_forward": "main_hall" }
},
```

The old `"entry2"`, `"entry3"`, `"entry4"` keys can stay — they are simply unreachable now.

- [ ] **Step 2: Verify JSON is valid**

```powershell
cd "C:\Users\gugom\OneDrive\Рабочий стол\Godot game"
Get-Content data\room_graph.json | ConvertFrom-Json | Select-Object -ExpandProperty rooms | Get-Member -MemberType NoteProperty | Select-Object Name
```

Expected output includes: `entry`, `entry_c1`, `entry_c2`, `entry_c3`, `entry_c4`, `closet`, `main_hall`, `corridor`, etc.

- [ ] **Step 3: Commit**

```powershell
git add data/room_graph.json
git commit -m "feat: rewire room graph — entry→corridor×2→closet→corridor×2→main_hall"
```

---

## Task 2: Rewrite room_entry.tscn

**Files:**
- Rewrite: `scenes/rooms/room_entry.tscn`

- [ ] **Step 1: Write the new scene file**

Replace the entire contents of `scenes/rooms/room_entry.tscn` with:

```
[gd_scene format=3 uid="uid://bwnn04woowr0b"]

[ext_resource type="Script" uid="uid://bn180b0k5nyen" path="res://scripts/rooms/room_entry_logic.gd" id="1_entry"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3_hud"]
[ext_resource type="PackedScene" uid="uid://2uqwlc1065aa" path="res://scenes/objects/examinable.tscn" id="4_exam"]

[sub_resource type="WorldBoundaryShape2D" id="FloorShape"]

[sub_resource type="RectangleShape2D" id="LeftWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="RightWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="ExitDoorShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[node name="RoomEntry" type="Node2D" unique_id=880896680]
script = ExtResource("1_entry")

[node name="Background" type="ColorRect" parent="." unique_id=1315570580]
offset_right = 1280.0
offset_bottom = 360.0
color = Color(0.04, 0.02, 0.06, 1)

[node name="Player" parent="." unique_id=1035253464 instance=ExtResource("2_player")]
position = Vector2(80, 290)

[node name="HUD" parent="." unique_id=1235727157 instance=ExtResource("3_hud")]

[node name="Floor" type="StaticBody2D" parent="." unique_id=330029861]
position = Vector2(0, 330)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor" unique_id=1431270059]
shape = SubResource("FloorShape")

[node name="LeftWall" type="StaticBody2D" parent="." unique_id=1299585735]
position = Vector2(-20, 350)

[node name="LeftWallShape" type="CollisionShape2D" parent="LeftWall" unique_id=1485990730]
position = Vector2(0, -176)
shape = SubResource("LeftWallShape")

[node name="RightWall" type="StaticBody2D" parent="." unique_id=1847392012]
position = Vector2(1280, 350)

[node name="RightWallShape" type="CollisionShape2D" parent="RightWall" unique_id=1847392013]
position = Vector2(0, -176)
shape = SubResource("RightWallShape")

[node name="SpawnPoint" type="Marker2D" parent="." unique_id=91499139]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="." unique_id=746070553]
position = Vector2(1280, 180)

[node name="RoomBottom" type="Marker2D" parent="." unique_id=1437339109]
position = Vector2(0, 360)

[node name="ExitDoorZone" type="Area2D" parent="." unique_id=1711091007]
position = Vector2(30, 260)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitDoorZone" unique_id=593362008]
shape = SubResource("ExitDoorShape")

[node name="ForwardZone" type="Area2D" parent="." unique_id=1545464917]
position = Vector2(1240, 260)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone" unique_id=613535758]
shape = SubResource("FwdShape")

[node name="ClothesExaminable" parent="." unique_id=563221368 instance=ExtResource("4_exam")]
position = Vector2(300, 270)
examine_text = "Довольно старинного вида одежда."
interaction_text = "Осмотреть"

[node name="WindowEntry" parent="." unique_id=2105272201 instance=ExtResource("4_exam")]
position = Vector2(700, 200)
examine_text = "Дорога едва видна под снегом. Следы уже замело. Обратного пути нет."
interaction_text = "Посмотреть в окно"
```

- [ ] **Step 2: Commit**

```powershell
git add scenes/rooms/room_entry.tscn
git commit -m "feat: rewrite room_entry — 1280px side-scroller format, player/hud/walls/zones"
```

---

## Task 3: Rewrite room_entry_logic.gd

**Files:**
- Rewrite: `scripts/rooms/room_entry_logic.gd`

- [ ] **Step 1: Write the new logic script**

Replace the entire contents of `scripts/rooms/room_entry_logic.gd` with:

```gdscript
extends Node2D

func _ready() -> void:
	# Camera limits — GameManager also sets these from RoomRight marker,
	# but setting here covers the initial game load edge case.
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

	# Show comment only on the second visit (escape_attempts == 1 means
	# the player tried to leave once before and was looped back here).
	if GameManager.escape_attempts == 1:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Что здесь происходит?", SubtitleManager.Pos.TOP_LEFT)

func _on_exit_door(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	GameManager.change_room("door_exit")  # door_exit → "entry" in room_graph = loop

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")  # door_forward → "entry_c1"
```

- [ ] **Step 2: Commit**

```powershell
git add scripts/rooms/room_entry_logic.gd
git commit -m "feat: rewrite room_entry_logic — exit loop, forward zone, escape_attempts comment"
```

---

## Task 4: Rewrite room_corridor.tscn

**Files:**
- Rewrite: `scenes/rooms/room_corridor.tscn`

- [ ] **Step 1: Write the new scene file**

Replace the entire contents of `scenes/rooms/room_corridor.tscn` with:

```
[gd_scene format=3 uid="uid://ceyj8lw7koq7e"]

[ext_resource type="Script" uid="uid://33qigk25a227" path="res://scripts/rooms/room_corridor_logic.gd" id="1_corr"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="2_player"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3_hud"]
[ext_resource type="PackedScene" uid="uid://laika001" path="res://scenes/characters/laika.tscn" id="4_laika"]
[ext_resource type="PackedScene" uid="uid://2uqwlc1065aa" path="res://scenes/objects/examinable.tscn" id="5_exam"]

[sub_resource type="WorldBoundaryShape2D" id="FloorShape"]

[sub_resource type="RectangleShape2D" id="LeftWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="RightWallShape"]
size = Vector2(40, 373)

[sub_resource type="RectangleShape2D" id="ExitShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="LaikaShape"]
size = Vector2(80, 160)

[node name="RoomCorridor" type="Node2D" unique_id=131571024]
script = ExtResource("1_corr")

[node name="Background" type="ColorRect" parent="." unique_id=769216410]
offset_right = 1600.0
offset_bottom = 360.0
color = Color(0.03, 0.02, 0.05, 1)

[node name="Player" parent="." unique_id=1035253465 instance=ExtResource("2_player")]
position = Vector2(80, 290)

[node name="HUD" parent="." unique_id=1235727158 instance=ExtResource("3_hud")]

[node name="Floor" type="StaticBody2D" parent="." unique_id=330029862]
position = Vector2(0, 330)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor" unique_id=1431270060]
shape = SubResource("FloorShape")

[node name="LeftWall" type="StaticBody2D" parent="." unique_id=1299585736]
position = Vector2(-20, 350)

[node name="LeftWallShape" type="CollisionShape2D" parent="LeftWall" unique_id=1485990731]
position = Vector2(0, -176)
shape = SubResource("LeftWallShape")

[node name="RightWall" type="StaticBody2D" parent="." unique_id=1847392014]
position = Vector2(1600, 350)

[node name="RightWallShape" type="CollisionShape2D" parent="RightWall" unique_id=1847392015]
position = Vector2(0, -176)
shape = SubResource("RightWallShape")

[node name="SpawnPoint" type="Marker2D" parent="." unique_id=406902745]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="." unique_id=1299071123]
position = Vector2(1600, 180)

[node name="RoomBottom" type="Marker2D" parent="." unique_id=755932259]
position = Vector2(0, 360)

[node name="ExitZone" type="Area2D" parent="." unique_id=1412378077]
position = Vector2(1560, 260)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitZone" unique_id=2066047497]
shape = SubResource("ExitShape")

[node name="WindowExamine" parent="." unique_id=156421091 instance=ExtResource("5_exam")]
position = Vector2(200, 200)
examine_text = "Темно за окном."
interaction_text = "Посмотреть в окно"

[node name="LaikaTrigger" type="Area2D" parent="." unique_id=874890696]
position = Vector2(700, 260)
collision_layer = 0

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaikaTrigger" unique_id=1636203791]
shape = SubResource("LaikaShape")

[node name="Laika" parent="." unique_id=157373864 instance=ExtResource("4_laika")]
position = Vector2(1100, 280)
auto_appear = false
```

Note: `WindowExamine.examine_text` is set to a placeholder here — `room_corridor_logic.gd` overwrites it in `_ready()` based on `GameManager.current_room`.

- [ ] **Step 2: Commit**

```powershell
git add scenes/rooms/room_corridor.tscn
git commit -m "feat: rewrite room_corridor — 1600px side-scroller format, player/hud/walls/laika, no SpiritGuardian"
```

---

## Task 5: Rewrite room_corridor_logic.gd

**Files:**
- Rewrite: `scripts/rooms/room_corridor_logic.gd`

- [ ] **Step 1: Write the new logic script**

Replace the entire contents of `scripts/rooms/room_corridor_logic.gd` with:

```gdscript
extends Node2D

var _window_examined: bool = false
var _laika_triggered: bool = false

func _ready() -> void:
	var room_id: String = GameManager.current_room

	# Camera limits — covers initial load edge case.
	var player := get_node_or_null("Player")
	if player:
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_right = 1600

	# Exit zone → always door_forward regardless of which corridor pass this is.
	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	# "Уходи." subtitle on entry_c3 only.
	if room_id == "entry_c3":
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)

	# Window examine text depends on which corridor pass this is.
	var window := get_node_or_null("WindowExamine")
	if window:
		_setup_window(window, room_id)

	# Laika only appears in entry_c4.
	if room_id == "entry_c4":
		var laika_trigger := get_node_or_null("LaikaTrigger")
		if laika_trigger:
			laika_trigger.body_entered.connect(_on_laika_trigger)

func _setup_window(window: Node, room_id: String) -> void:
	match room_id:
		"entry_c1", "entry_c2":
			window.examine_text = "Двор. Снег по колено, ничего не разобрать."
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "..."
			)
		"entry_c3":
			window.examine_text = "Мне кажется, или кто-то смотрит в ответ из темноты?"
			window.examined.connect(func():
				if not _window_examined:
					_window_examined = true
					window.examine_text = "..."
			)
		"entry_c4":
			# No repeat — single text, no callback needed.
			window.examine_text = "Дорога едва видна под снегом. Следы уже замело. Обратного пути нет."
		_:
			window.examine_text = "Темно за окном."

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

```powershell
git add scripts/rooms/room_corridor_logic.gd
git commit -m "feat: rewrite room_corridor_logic — per-room_id window text, Ukhodi subtitle, Laika on entry_c4"
```

---

## Task 6: Manual Verification

**Goal:** Walk through the full chain in-game and verify every behaviour from the spec.

- [ ] **Step 1: Open Godot and set start room to "entry"**

In `scripts/autoload/game_manager.gd`, temporarily change:
```gdscript
var current_room: String = "entry"
```
Run the project (F5).

- [ ] **Step 2: Verify room_entry basics**

- Player spawns at left side, can walk right ✓  
- Camera scrolls, stops at x=1280 ✓  
- Examine шуба → dialogue "Довольно старинного вида одежда." ✓  
- Examine окно → dialogue "Дорога едва видна..." ✓  
- No subtitles on first load ✓  

- [ ] **Step 3: Verify exit loop**

- Walk left into ExitDoorZone → screen fades, re-enters entry ✓  
- Subtitle "Что здесь происходит?" appears on this second visit ✓  
- Walk left again → no subtitle (silent loop) ✓  

- [ ] **Step 4: Verify corridor chain — entry_c1**

- Walk right in entry → entry_c1 loads ✓  
- Examine окно → "Двор. Снег по колено, ничего не разобрать." ✓  
- Examine окно again → "..." ✓  
- Walk right → entry_c2 loads ✓  

- [ ] **Step 5: Verify corridor chain — entry_c2 and closet**

- entry_c2: examine окно → same yard text ✓  
- Walk right → closet loads ✓  
- Complete closet → entry_c3 loads ✓  

- [ ] **Step 6: Verify entry_c3**

- Subtitle "Уходи." appears on entry ✓  
- Examine окно → "Мне кажется, или кто-то смотрит в ответ из темноты?" ✓  
- Examine окно again → "..." ✓  
- Walk right → entry_c4 loads ✓  

- [ ] **Step 7: Verify entry_c4 Laika**

- Walk to x≈700 → Laika appears ✓  
- Dialogue "Опять эта лайка… Возможно, она ведёт меня куда-то?" ✓  
- Laika walks right and fades out ✓  
- Examine окно → "Дорога едва видна под снегом..." (no repeat) ✓  
- Walk right → main_hall loads ✓  

- [ ] **Step 8: Revert start room**

Restore `game_manager.gd`:
```gdscript
var current_room: String = "main_hall"
```

- [ ] **Step 9: Final commit**

```powershell
git add scripts/autoload/game_manager.gd
git commit -m "fix: restore default start room to main_hall after entry/corridor testing"
```
