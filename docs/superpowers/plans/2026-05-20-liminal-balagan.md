# Liminal Balagan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add liminal corridors, repeating rooms, Kydaana subtitle system, and Naayda emotional arc to create a trapped, PT-style balagan experience.

**Architecture:** Six new room scenes share two reusable scripts (room_entry_logic, room_corridor_logic) determined by `GameManager.current_room`. SubtitleManager autoload handles all Kydaana whispers with a 90-second cooldown. Naayda appears via trigger zones in existing and new rooms. room_graph.json fully replaces the old linear path.

**Tech Stack:** Godot 4.6, GDScript typed, existing Interactable/Door/Examinable/Pickable scene templates, existing DialogueManager/GameManager/ChapterManager autoloads.

---

## File Map

| Action | File |
|---|---|
| Modify | `scripts/autoload/game_manager.gd` |
| Modify | `scripts/autoload/save_manager.gd` |
| Create | `scripts/autoload/subtitle_manager.gd` |
| Modify | `project.godot` |
| Create | `scripts/rooms/room_entry_logic.gd` |
| Create | `scripts/rooms/room_corridor_logic.gd` |
| Create | `scripts/rooms/room_closet_logic.gd` |
| Create | `scripts/rooms/room_dining_logic.gd` |
| Create | `scripts/rooms/room_storage_logic.gd` |
| Create | `scripts/rooms/room_kydaana_logic.gd` |
| Create | `scenes/rooms/room_entry.tscn` |
| Create | `scenes/rooms/room_corridor.tscn` |
| Create | `scenes/rooms/room_closet.tscn` |
| Create | `scenes/rooms/room_dining.tscn` |
| Create | `scenes/rooms/room_storage.tscn` |
| Create | `scenes/rooms/room_kydaana.tscn` |
| Modify | `data/room_graph.json` |
| Modify | `scripts/autoload/chapter_manager.gd` |
| Modify | `scripts/rooms/room_main_hall_logic.gd` |
| Modify | `scripts/rooms/room_forest_logic.gd` |
| Modify | `scripts/rooms/finale.gd` |
| Modify | `data/dialogues/notes.json` |

---

## Task 1: GameManager — escape_attempts + SubtitleManager autoload

**Files:**
- Modify: `scripts/autoload/game_manager.gd`
- Modify: `scripts/autoload/save_manager.gd`
- Create: `scripts/autoload/subtitle_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Add escape_attempts to game_manager.gd**

Open `scripts/autoload/game_manager.gd`. After line `var loop_state: int = 0` add:

```gdscript
var escape_attempts: int = 0
```

In `restore_from_save()`, after `loop_state = artifacts_collected.size()`, add nothing — escape_attempts intentionally resets on load (player re-discovers the trap).

- [ ] **Step 2: Create subtitle_manager.gd**

Create `scripts/autoload/subtitle_manager.gd` with full content:

```gdscript
extends CanvasLayer

enum Pos {
	TOP_LEFT, TOP_CENTER, TOP_RIGHT,
	MID_LEFT, MID_RIGHT,
	BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT
}

const ANCHORS: Dictionary = {
	Pos.TOP_LEFT:      Vector2(0.10, 0.10),
	Pos.TOP_CENTER:    Vector2(0.50, 0.08),
	Pos.TOP_RIGHT:     Vector2(0.85, 0.10),
	Pos.MID_LEFT:      Vector2(0.08, 0.50),
	Pos.MID_RIGHT:     Vector2(0.82, 0.50),
	Pos.BOTTOM_LEFT:   Vector2(0.10, 0.85),
	Pos.BOTTOM_CENTER: Vector2(0.50, 0.88),
	Pos.BOTTOM_RIGHT:  Vector2(0.85, 0.85),
}

const COOLDOWN: float = 90.0

var _cooldown_timer: float = 0.0
var _label: Label = null

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 0.80, 0.90, 1.0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.size = Vector2(260, 60)
	_label.modulate.a = 0.0
	add_child(_label)

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

func show_subtitle(text: String, pos: Pos) -> void:
	if _cooldown_timer > 0.0:
		return
	_cooldown_timer = COOLDOWN
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var anchor: Vector2 = ANCHORS[pos]
	_label.text = text
	_label.position = anchor * vp - _label.size * 0.5
	_label.modulate.a = 0.0
	var hang: float = clampf(text.length() * 0.06, 3.0, 5.0)
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hang)
	tw.tween_property(_label, "modulate:a", 0.0, 1.2)

func show_subtitle_pair(text1: String, pos1: Pos, delay: float, text2: String, pos2: Pos) -> void:
	show_subtitle(text1, pos1)
	await get_tree().create_timer(delay + 0.8).timeout
	_cooldown_timer = 0.0
	show_subtitle(text2, pos2)
```

- [ ] **Step 3: Register SubtitleManager in project.godot**

Open `project.godot`. In the `[autoload]` section, after the last autoload line, add:

```
SubtitleManager="*res://scripts/autoload/subtitle_manager.gd"
```

- [ ] **Step 4: Commit**

```
git add scripts/autoload/game_manager.gd scripts/autoload/subtitle_manager.gd project.godot
git commit -m "feat: escape_attempts counter + SubtitleManager autoload"
```

---

## Task 2: room_entry_logic.gd + room_entry.tscn (Сени)

**Files:**
- Create: `scripts/rooms/room_entry_logic.gd`
- Create: `scenes/rooms/room_entry.tscn`

- [ ] **Step 1: Create room_entry_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	var room_id: String = GameManager.current_room

	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	# Naayda trigger: appears before Зал on the entry2 pass
	if room_id == "entry2":
		_setup_naayda()

	# Subtitle: first step into balagan
	if room_id == "entry" and GameManager.escape_attempts == 0 and GameManager.transition_count <= 2:
		await get_tree().process_frame
		await get_tree().process_frame
		SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)

	# Clothes examinable
	var clothes := get_node_or_null("ClothesExaminable")
	if clothes:
		clothes.examined.connect(func():
			SubtitleManager.show_subtitle("Не трогай.", SubtitleManager.Pos.MID_LEFT)
		)

func _on_exit_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	GameManager.escape_attempts += 1
	match GameManager.escape_attempts:
		2:
			SubtitleManager.show_subtitle("Ты не выйдешь.", SubtitleManager.Pos.BOTTOM_RIGHT)
		3:
			SubtitleManager.show_subtitle("Отсюда нет выхода.", SubtitleManager.Pos.TOP_CENTER)
	GameManager.change_room("door_exit")

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _setup_naayda() -> void:
	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	await get_tree().create_timer(1.2).timeout
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = false
	var tw := create_tween()
	tw.tween_property(laika, "global_position:x", laika.global_position.x + 300.0, 1.0)
	tw.parallel().tween_property(laika, "modulate:a", 0.0, 1.0)
	await tw.finished
	laika.visible = false
```

- [ ] **Step 2: Create room_entry.tscn**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_entry_logic.gd" id="1_entry"]
[ext_resource type="PackedScene" path="res://scenes/characters/laika.tscn" id="2_laika"]
[ext_resource type="PackedScene" path="res://scenes/objects/examinable.tscn" id="3_exam"]

[sub_resource type="RectangleShape2D" id="ExitShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="LaikaShape"]
size = Vector2(80, 160)

[node name="RoomEntry" type="Node2D"]
script = ExtResource("1_entry")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.04, 0.02, 0.06, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(320, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ExitZone" type="Area2D" parent="."]
position = Vector2(30, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ExitZone"]
shape = SubResource("ExitShape")

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="ClothesExaminable" parent="." instance=ExtResource("3_exam")]
position = Vector2(200, 270)
interaction_text = "Осмотреть"
examine_text = "Тяжёлая шуба. Чья-то — не понять. Давно не надевали."

[node name="LaikaTrigger" type="Area2D" parent="."]
position = Vector2(420, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaikaTrigger"]
shape = SubResource("LaikaShape")

[node name="Laika" parent="." instance=ExtResource("2_laika")]
position = Vector2(560, 280)
auto_appear = false
```

- [ ] **Step 3: Manual verify**

Run the project. From the Godot editor, temporarily set `run/main_scene` to `room_entry.tscn` or navigate to it via room_graph. Confirm:
- Background is dark purple
- Player spawns in center
- Walking left into ExitZone → GameManager.change_room("door_exit") called (will error since room_graph not yet updated — that's fine for now)

- [ ] **Step 4: Commit**

```
git add scripts/rooms/room_entry_logic.gd scenes/rooms/room_entry.tscn
git commit -m "feat: room_entry (Сени) — escape loop + Naayda trigger"
```

---

## Task 3: room_corridor_logic.gd + room_corridor.tscn (Коридор)

**Files:**
- Create: `scripts/rooms/room_corridor_logic.gd`
- Create: `scenes/rooms/room_corridor.tscn`

- [ ] **Step 1: Create room_corridor_logic.gd**

```gdscript
extends Node2D

var _naayda_triggered: bool = false

func _ready() -> void:
	var room_id: String = GameManager.current_room

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	# Subtitle varies by room_id / artifact state
	await get_tree().process_frame
	_maybe_show_subtitle(room_id)

	# Naayda: appears in first corridor before Спальня
	if room_id == "corridor":
		var laika_trigger := get_node_or_null("LaikaTrigger")
		if laika_trigger:
			laika_trigger.body_entered.connect(_on_laika_trigger)

func _maybe_show_subtitle(room_id: String) -> void:
	var has_amulet: bool = GameManager.artifacts_collected.has("amulet")
	var has_doll: bool = GameManager.artifacts_collected.has("doll")
	match room_id:
		"corridor":
			if has_amulet and not has_doll:
				SubtitleManager.show_subtitle("Зачем ты это делаешь?", SubtitleManager.Pos.MID_LEFT)
		"corridor2":
			if has_doll:
				SubtitleManager.show_subtitle("Это не поможет.", SubtitleManager.Pos.MID_RIGHT)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _naayda_triggered:
		return
	_naayda_triggered = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.appear()
	await get_tree().create_timer(1.0).timeout
	var tw := create_tween()
	tw.tween_property(laika, "global_position:x", laika.global_position.x + 400.0, 1.2)
	tw.parallel().tween_property(laika, "modulate:a", 0.0, 1.2)
	await tw.finished
	laika.visible = false
```

- [ ] **Step 2: Create room_corridor.tscn**

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_corridor_logic.gd" id="1_corr"]
[ext_resource type="PackedScene" path="res://scenes/characters/laika.tscn" id="2_laika"]
[ext_resource type="PackedScene" path="res://scenes/characters/spirit_guardian.tscn" id="3_spirit"]

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="LaikaShape"]
size = Vector2(80, 160)

[node name="RoomCorridor" type="Node2D"]
script = ExtResource("1_corr")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.03, 0.02, 0.05, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="LaikaTrigger" type="Area2D" parent="."]
position = Vector2(400, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaikaTrigger"]
shape = SubResource("LaikaShape")

[node name="Laika" parent="." instance=ExtResource("2_laika")]
position = Vector2(560, 280)
auto_appear = false

[node name="SpiritGuardian" parent="." instance=ExtResource("3_spirit")]
position = Vector2(300, 280)
```

- [ ] **Step 3: Commit**

```
git add scripts/rooms/room_corridor_logic.gd scenes/rooms/room_corridor.tscn
git commit -m "feat: room_corridor (Коридор) — spirit + Naayda trigger"
```

---

## Task 4: room_closet_logic.gd + room_closet.tscn (Чулан)

**Files:**
- Create: `scripts/rooms/room_closet_logic.gd`
- Create: `scenes/rooms/room_closet.tscn`

- [ ] **Step 1: Create room_closet_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

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

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 2: Create room_closet.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_closet_logic.gd" id="1_clos"]
[ext_resource type="PackedScene" path="res://scenes/objects/examinable.tscn" id="2_exam"]

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[node name="RoomCloset" type="Node2D"]
script = ExtResource("1_clos")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.05, 0.03, 0.04, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="KapkansExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(280, 270)
interaction_text = "Осмотреть"
examine_text = "Ржавые капканы. Один сломан — пружина лопнула. Давно."

[node name="ChestExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(420, 270)
interaction_text = "Осмотреть"
examine_text = "Деревянный ларец. Внутри — записка."
```

- [ ] **Step 3: Commit**

```
git add scripts/rooms/room_closet_logic.gd scenes/rooms/room_closet.tscn
git commit -m "feat: room_closet (Чулан) — father notes + subtitle"
```

---

## Task 5: room_dining_logic.gd + room_dining.tscn (Столовая)

**Files:**
- Create: `scripts/rooms/room_dining_logic.gd`
- Create: `scenes/rooms/room_dining.tscn`

- [ ] **Step 1: Create room_dining_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	var homuz := get_node_or_null("HomuzExaminable")
	if homuz:
		homuz.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Мать играла каждый вечер. Я засыпала под него.",
				SubtitleManager.Pos.BOTTOM_CENTER
			)
		)

	var table := get_node_or_null("TableExaminable")
	if table:
		table.examined.connect(func():
			GameManager.mark_note_found("note_mother_2")
			DialogueManager.start_dialogue("notes/note_mother_2")
		)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Мы ели здесь все вместе. Давно.",
		SubtitleManager.Pos.BOTTOM_LEFT
	)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 2: Create room_dining.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_dining_logic.gd" id="1_dine"]
[ext_resource type="PackedScene" path="res://scenes/objects/examinable.tscn" id="2_exam"]

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[node name="RoomDining" type="Node2D"]
script = ExtResource("1_dine")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.05, 0.04, 0.03, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="HomuzExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(420, 260)
interaction_text = "Осмотреть"
examine_text = "Хомус. Одна пластина чуть погнута — починена старательно, много раз."

[node name="TableExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(280, 270)
interaction_text = "Осмотреть"
examine_text = "Стол. На нём — остатки последней трапезы. Чашки перевёрнуты."
```

- [ ] **Step 3: Commit**

```
git add scripts/rooms/room_dining_logic.gd scenes/rooms/room_dining.tscn
git commit -m "feat: room_dining (Столовая) — mother note + homuz subtitle"
```

---

## Task 6: room_storage_logic.gd + room_storage.tscn (Кладовая)

**Files:**
- Create: `scripts/rooms/room_storage_logic.gd`
- Create: `scenes/rooms/room_storage.tscn`

- [ ] **Step 1: Create room_storage_logic.gd**

```gdscript
extends Node2D

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

	var note_env3 := get_node_or_null("NoteEnv3")
	if note_env3:
		note_env3.examined.connect(func():
			GameManager.mark_note_found("note_env_3")
			DialogueManager.start_dialogue("notes/note_env_3")
		)

	await get_tree().process_frame
	await get_tree().process_frame
	SubtitleManager.show_subtitle(
		"Запасов хватило бы до весны. Но весны не было.",
		SubtitleManager.Pos.TOP_CENTER
	)

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")
```

- [ ] **Step 2: Create room_storage.tscn**

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_storage_logic.gd" id="1_stor"]
[ext_resource type="PackedScene" path="res://scenes/objects/examinable.tscn" id="2_exam"]

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[node name="RoomStorage" type="Node2D"]
script = ExtResource("1_stor")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.04, 0.03, 0.03, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="BagsExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(260, 270)
interaction_text = "Осмотреть"
examine_text = "Пустые мешки. Кожа высохла и потрескалась."

[node name="NoteEnv3" parent="." instance=ExtResource("2_exam")]
position = Vector2(400, 260)
interaction_text = "Прочитать"
examine_text = "На бересте — несколько слов."
```

- [ ] **Step 3: Commit**

```
git add scripts/rooms/room_storage_logic.gd scenes/rooms/room_storage.tscn
git commit -m "feat: room_storage (Кладовая) — env note + subtitle"
```

---

## Task 7: room_kydaana_logic.gd + room_kydaana.tscn (mirror puzzle migration)

**Files:**
- Create: `scripts/rooms/room_kydaana_logic.gd`
- Create: `scenes/rooms/room_kydaana.tscn`

- [ ] **Step 1: Create room_kydaana_logic.gd**

This script is adapted from `room_basement_logic.gd` with Naayda behavior added.

```gdscript
extends Node2D

var _mirror_minigame_active: bool = false
var _mirror_solved: bool = false
var _naayda_greeted: bool = false

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		for node_name: String in ["KeyPickable", "ChestEarring", "EarringPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		var door := get_node_or_null("ForwardZone")
		if door:
			pass  # Already navigable
		return

	await get_tree().process_frame
	_setup_naayda()

	var riddle := get_node_or_null("RiddleMirror")
	if riddle:
		riddle.examined.connect(func():
			DialogueManager.start_dialogue("notes/riddle_mirror")
			GameManager.mark_note_found("riddle_mirror")
		)

	var mirror := get_node_or_null("OldMirror")
	if mirror:
		mirror.examined.connect(_on_mirror_examined)

	var drawings := get_node_or_null("DrawingsExaminable")
	if drawings:
		drawings.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Я нарисовала это когда думала что всё будет хорошо.",
				SubtitleManager.Pos.TOP_LEFT
			)
		)

	var clothes := get_node_or_null("ClothesExaminable")
	if clothes:
		clothes.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Я её больше не надену.",
				SubtitleManager.Pos.MID_RIGHT
			)
		)

	var bed := get_node_or_null("BedExaminable")
	if bed:
		bed.examined.connect(func():
			SubtitleManager.show_subtitle(
				"Здесь я видела сны. Хорошие — в начале.",
				SubtitleManager.Pos.TOP_CENTER
			)
		)

	var note5 := get_node_or_null("NoteKydaana5")
	if note5:
		note5.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_5")
			GameManager.mark_note_found("note_kydaana_5")
		)

	var note4 := get_node_or_null("NoteKydaana4")
	if note4:
		note4.examined.connect(func():
			DialogueManager.start_dialogue("notes/note_kydaana_4")
			GameManager.mark_note_found("note_kydaana_4")
		)

	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): _on_earring_picked_up())

	var chest := get_node_or_null("ChestEarring")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var floorboard := get_node_or_null("SecretFloorboard")
	if floorboard:
		floorboard.examined.connect(_on_floorboard_examined)

	var forward_zone := get_node_or_null("ForwardZone")
	if forward_zone:
		forward_zone.body_entered.connect(_on_forward_zone)

	SubtitleManager.show_subtitle_pair(
		"Не трогай мои вещи.",
		SubtitleManager.Pos.TOP_RIGHT,
		3.0,
		"...пожалуйста.",
		SubtitleManager.Pos.BOTTOM_LEFT
	)

func _setup_naayda() -> void:
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	laika.sit_at(laika.global_position)
	laika.appear()
	var approach_zone := get_node_or_null("LaikaTrigger")
	if approach_zone:
		approach_zone.body_entered.connect(_on_approach_naayda)

func _on_approach_naayda(body: Node2D) -> void:
	if not body.is_in_group("player") or _naayda_greeted:
		return
	_naayda_greeted = true
	var laika := get_node_or_null("Laika")
	if not laika:
		return
	var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.flip_h = true
	await get_tree().create_timer(1.5).timeout
	var tw := create_tween()
	tw.tween_property(laika, "modulate:a", 0.0, 1.5)
	await tw.finished
	laika.visible = false

func _on_mirror_examined() -> void:
	if _mirror_minigame_active:
		return
	if _mirror_solved:
		DialogueManager.show_text("", "Зеркало собрано. Ты помнишь — третья доска от окна, где сучок звездой.")
		return
	SubtitleManager.show_subtitle(
		"Оно разбилось в ту ночь. Я не смотрелась с тех пор.",
		SubtitleManager.Pos.MID_LEFT
	)
	DialogueManager.start_dialogue("notes/riddle_mirror")
	await DialogueManager.dialogue_finished
	_launch_mirror_minigame()

func _launch_mirror_minigame() -> void:
	_mirror_minigame_active = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("freeze"):
		player.freeze()
	var scene := preload("res://scenes/minigames/minigame_mirror.tscn")
	var mg: MinigameMirror = scene.instantiate()
	get_tree().current_scene.add_child(mg)
	mg.minigame_completed.connect(_on_mirror_solved_signal)
	mg.minigame_cancelled.connect(_on_mirror_cancelled)

func _on_mirror_solved_signal(_id: String) -> void:
	_mirror_minigame_active = false
	_mirror_solved = true
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()
	DialogueManager.show_text("", "Зеркало собралось. В нём — отражение комнаты. Там, где сучок в доске похож на звезду, что-то спрятано.")
	await DialogueManager.dialogue_finished
	var floorboard := get_node_or_null("SecretFloorboard")
	if floorboard:
		floorboard.visible = true
		floorboard.set_deferred("monitoring", true)

func _on_mirror_cancelled() -> void:
	_mirror_minigame_active = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("unfreeze"):
		player.unfreeze()

func _on_floorboard_examined() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_chest_used() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_trigger_flashback()

func _on_forward_zone(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_forward")

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tw := create_tween()
	tw.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tw.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_earring")
	await DialogueManager.dialogue_finished
	tw = create_tween()
	tw.tween_property(bg, "color", original_color, 1.0)
	await tw.finished
	if fl:
		fl.scripted_on()
```

- [ ] **Step 2: Create room_kydaana.tscn**

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/rooms/room_kydaana_logic.gd" id="1_kyd"]
[ext_resource type="PackedScene" path="res://scenes/objects/examinable.tscn" id="2_exam"]
[ext_resource type="PackedScene" path="res://scenes/objects/pickable.tscn" id="3_pick"]
[ext_resource type="PackedScene" path="res://scenes/characters/laika.tscn" id="4_laika"]

[sub_resource type="RectangleShape2D" id="FwdShape"]
size = Vector2(60, 140)

[sub_resource type="RectangleShape2D" id="LaikaShape"]
size = Vector2(100, 160)

[node name="RoomKydaana" type="Node2D"]
script = ExtResource("1_kyd")

[node name="Background" type="ColorRect" parent="."]
offset_right = 640.0
offset_bottom = 360.0
color = Color(0.06, 0.04, 0.07, 1)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(80, 290)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(640, 0)

[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 360)

[node name="ForwardZone" type="Area2D" parent="."]
position = Vector2(590, 260)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="ForwardZone"]
shape = SubResource("FwdShape")

[node name="OldMirror" parent="." instance=ExtResource("2_exam")]
position = Vector2(480, 220)
interaction_text = "Осмотреть"
examine_text = "Разбитое зеркало в деревянной раме."

[node name="RiddleMirror" parent="." instance=ExtResource("2_exam")]
position = Vector2(500, 200)
interaction_text = "Прочитать"
examine_text = "Царапина на раме — слова."

[node name="BedExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(200, 270)
interaction_text = "Осмотреть"
examine_text = "Узкая кровать. Лоскутное одеяло, аккуратно сложено."

[node name="DrawingsExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(340, 200)
interaction_text = "Осмотреть"
examine_text = "Детские рисунки — наклеены прямо на бревно. Дом, собака, солнце."

[node name="ClothesExaminable" parent="." instance=ExtResource("2_exam")]
position = Vector2(120, 230)
interaction_text = "Осмотреть"
examine_text = "Праздничная одежда. Вышивка по воротнику — северный орнамент."

[node name="NoteKydaana4" parent="." instance=ExtResource("2_exam")]
position = Vector2(280, 260)
interaction_text = "Прочитать"
examine_text = "Несколько строк на свёрнутом листе."

[node name="NoteKydaana5" parent="." instance=ExtResource("2_exam")]
position = Vector2(380, 260)
interaction_text = "Прочитать"
examine_text = "Последняя записка."

[node name="SecretFloorboard" parent="." instance=ExtResource("2_exam")]
position = Vector2(300, 310)
interaction_text = "Осмотреть"
examine_text = "Половица с необычным сучком — похожим на звезду."
visible = false

[node name="EarringPickable" parent="." instance=ExtResource("3_pick")]
position = Vector2(300, 295)
item_id = "earring"
item_name = "Серёжка"
pickup_text = "Серёжка. Одна. Вторую ты уже не найдёшь."
visible = false

[node name="Laika" parent="." instance=ExtResource("4_laika")]
position = Vector2(210, 285)
auto_appear = false

[node name="LaikaTrigger" type="Area2D" parent="."]
position = Vector2(230, 270)
collision_layer = 0
collision_mask = 1

[node name="CollisionShape2D" type="CollisionShape2D" parent="LaikaTrigger"]
shape = SubResource("LaikaShape")
```

- [ ] **Step 3: Archive room_basement**

```
git mv scenes/rooms/room_basement.tscn _legacy/room_basement.tscn
git mv scripts/rooms/room_basement_logic.gd _legacy/room_basement_logic.gd
```

- [ ] **Step 4: Commit**

```
git add scripts/rooms/room_kydaana_logic.gd scenes/rooms/room_kydaana.tscn _legacy/
git commit -m "feat: room_kydaana (Комната Кыдааны) — mirror puzzle + Naayda sit + archive basement"
```

---

## Task 8: room_graph.json — полная замена

**Files:**
- Modify: `data/room_graph.json`

- [ ] **Step 1: Replace room_graph.json entirely**

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
      "doors": { "door_forward": "closet", "door_exit": "main_hall" }
    },
    "closet": {
      "scene": "res://scenes/rooms/room_closet.tscn",
      "doors": { "door_forward": "entry2" }
    },
    "entry2": {
      "scene": "res://scenes/rooms/room_entry.tscn",
      "doors": { "door_forward": "main_hall", "door_exit": "main_hall" }
    },
    "main_hall": {
      "scene": "res://scenes/rooms/room_main_hall.tscn",
      "doors": { "door_bedroom": "corridor" }
    },
    "corridor": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "dining" }
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
      "doors": { "door_forward": "corridor3" }
    },
    "corridor3": {
      "scene": "res://scenes/rooms/room_corridor.tscn",
      "doors": { "door_forward": "storage" }
    },
    "storage": {
      "scene": "res://scenes/rooms/room_storage.tscn",
      "doors": { "door_forward": "kydaana_room" }
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
git commit -m "feat: room_graph — full liminal path replaces old linear layout"
```

---

## Task 9: ChapterManager — BALAGAN starts at entry

**Files:**
- Modify: `scripts/autoload/chapter_manager.gd`

- [ ] **Step 1: Update _get_chapter_scene and _get_chapter_room**

In `chapter_manager.gd`, replace `_get_chapter_scene` and `_get_chapter_room`:

```gdscript
func _get_chapter_scene(chapter: Chapter) -> String:
	match chapter:
		Chapter.ROAD:
			var path := "res://scenes/rooms/room_highway.tscn"
			return path if ResourceLoader.exists(path) else "res://scenes/rooms/room_entry.tscn"
		Chapter.BALAGAN:
			return "res://scenes/rooms/room_entry.tscn"
		Chapter.RELEASE:
			return "res://scenes/rooms/room_finale.tscn"
	return "res://scenes/rooms/room_entry.tscn"

func _get_chapter_room(chapter: Chapter) -> String:
	match chapter:
		Chapter.ROAD: return "highway"
		Chapter.BALAGAN: return "entry"
		Chapter.RELEASE: return "finale"
	return "entry"
```

- [ ] **Step 2: Commit**

```
git add scripts/autoload/chapter_manager.gd
git commit -m "fix: ChapterManager BALAGAN now starts at entry (Сени)"
```

---

## Task 10: room_main_hall_logic.gd — силуэт + одна попытка ритуала + субтитры

**Files:**
- Modify: `scripts/rooms/room_main_hall_logic.gd`

- [ ] **Step 1: Add idle subtitle timer**

After `var kamylok_state: KamylokState = KamylokState.COLD`, add:

```gdscript
var _idle_subtitle_timer: float = 0.0
var _idle_subtitle_shown: bool = false
```

Add at end of file:

```gdscript
func _process(delta: float) -> void:
	if _idle_subtitle_shown:
		return
	_idle_subtitle_timer += delta
	if _idle_subtitle_timer >= 10.0:
		_idle_subtitle_shown = true
		SubtitleManager.show_subtitle("Зачем ты здесь стоишь?", SubtitleManager.Pos.MID_RIGHT)
```

- [ ] **Step 2: Add return-to-hall subtitle in _ready**

At the end of `_ready()`, add:

```gdscript
if _all_artifacts_collected():
	await get_tree().process_frame
	SubtitleManager.show_subtitle("Ты дошёл.", SubtitleManager.Pos.TOP_CENTER)
```

- [ ] **Step 3: Replace RITUAL_READY text and make ritual one-attempt**

Find `KamylokState.RITUAL_READY:` block and replace:

```gdscript
KamylokState.RITUAL_READY:
	kamylok_state = KamylokState.RITUAL_ACTIVE
	DialogueManager.show_text("", "Пламя ждёт.")
```

Find `_complete_ritual()` and replace entirely:

```gdscript
func _complete_ritual() -> void:
	if ritual_items == CORRECT_ORDER:
		var tween := create_tween()
		var bg := $Background as ColorRect
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
```

- [ ] **Step 4: Add Kydaana dark silhouette after amulet pickup**

Find `_on_amulet_picked_up()` and replace:

```gdscript
func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	await _trigger_flashback("notes/artifact_amulet")
	_show_kydaana_silhouette()

func _show_kydaana_silhouette() -> void:
	var silhouette := Sprite2D.new()
	silhouette.texture = load("res://assets/sprites/spirit_placeholder.png")
	silhouette.modulate = Color(0.05, 0.02, 0.1, 0.0)
	silhouette.position = Vector2(520, 260)
	silhouette.scale = Vector2(1.2, 1.5)
	add_child(silhouette)

	var tw := create_tween()
	tw.tween_property(silhouette, "modulate:a", 0.8, 1.5)
	tw.tween_interval(3.5)
	tw.tween_property(silhouette, "modulate:a", 0.0, 1.5)
	await tw.finished
	silhouette.queue_free()

	SubtitleManager.show_subtitle("Ты видел меня.", SubtitleManager.Pos.TOP_RIGHT)
```

- [ ] **Step 5: Add door_bedroom → corridor (update node connection)**

In `_setup_puzzle()`, after the poem connection, find `var note1 :=` block. Before it, add:

```gdscript
var door_bedroom := get_node_or_null("DoorBedroom")
if door_bedroom and door_bedroom.has_method("interact"):
	pass  # door_id set in scene to "door_bedroom" — room_graph routes to corridor
```

(No code change needed here — the door node in the scene uses `door_id = "door_bedroom"` which room_graph now routes to `corridor`. This is just a note to verify the scene has this door.)

- [ ] **Step 6: Commit**

```
git add scripts/rooms/room_main_hall_logic.gd
git commit -m "feat: main_hall — Kydaana silhouette, one-attempt ritual, return subtitle"
```

---

## Task 11: room_forest_logic.gd — Naayda first appearance

**Files:**
- Modify: `scripts/rooms/room_forest_logic.gd`

- [ ] **Step 1: Update _on_laika_trigger to not use "Наайда" phrase twice**

The existing `_on_laika_trigger` already works and shows "Наайда... Она здесь? Откуда?". Keep it. Only change: update `_on_exit_zone` so it navigates to "entry" via ChapterManager (already works since ChapterManager.BALAGAN now starts at "entry" — no code change needed here).

Verify current `_on_exit_zone`:
```gdscript
func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player") and not _chapter_started:
		_chapter_started = true
		ChapterManager.start_chapter(ChapterManager.Chapter.BALAGAN)
```

This calls `ChapterManager.start_chapter(BALAGAN)` which now loads `room_entry.tscn`. ✓ No changes needed.

- [ ] **Step 2: Commit**

```
git add scripts/rooms/room_forest_logic.gd
git commit -m "chore: forest_logic verified — exit now routes to entry via ChapterManager"
```

---

## Task 12: finale.gd — Наайда nose touch

**Files:**
- Modify: `scripts/rooms/finale.gd`

- [ ] **Step 1: Replace Naayda sequence in _start_good_ending**

Find the laika section in `_start_good_ending()`:

```gdscript
if laika:
	laika.follow_player()

DialogueManager.start_dialogue("finale/good_part2")
await DialogueManager.dialogue_finished

if laika:
	var laika_tween := create_tween()
	laika.glow.energy = 1.0
	laika_tween.tween_property(laika, "modulate:a", 0.0, 3.0)
	laika_tween.parallel().tween_property(laika.glow, "energy", 2.0, 1.5)
	laika_tween.parallel().tween_property(laika.glow, "energy", 0.0, 1.5).set_delay(1.5)
	await get_tree().create_timer(1.5).timeout
	DialogueManager.show_text("", "Тихий скулёж. Она светится — так же, как Кыдаана.")
	await DialogueManager.dialogue_finished
	await laika_tween.finished
```

Replace with:

```gdscript
DialogueManager.start_dialogue("finale/good_part2")
await DialogueManager.dialogue_finished

if laika:
	# Наайда подходит впервые — не убегает
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var target_x: float = player.global_position.x + 40.0
		var approach_tw := create_tween()
		approach_tw.tween_property(laika, "global_position:x", target_x, 1.5)
		await approach_tw.finished

	await get_tree().create_timer(0.8).timeout
	DialogueManager.show_text("", "Она подходит. Впервые — не убегает.")
	await DialogueManager.dialogue_finished

	# Nose touch moment
	await get_tree().create_timer(0.5).timeout
	DialogueManager.show_text("", "Тычется носом в руку. Тепло. Живое.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(0.8).timeout
	DialogueManager.show_text("", "Смотрит на Кыдаану. Потом — на тебя. И снова на неё.")
	await DialogueManager.dialogue_finished

	# Fade together
	laika.glow.energy = 1.0
	var fade_tw := create_tween()
	fade_tw.tween_property(laika, "modulate:a", 0.0, 3.0)
	fade_tw.parallel().tween_property(laika.glow, "energy", 2.0, 1.5)
	fade_tw.parallel().tween_property(laika.glow, "energy", 0.0, 1.5).set_delay(1.5)
	await get_tree().create_timer(1.5).timeout
	DialogueManager.show_text("", "Она уходит вместе с ней. В свет.")
	await DialogueManager.dialogue_finished
	await fade_tw.finished
```

- [ ] **Step 2: Commit**

```
git add scripts/rooms/finale.gd
git commit -m "feat: finale — Naayda nose touch approach sequence"
```

---

## Task 13: notes.json + bedroom_logic forward door

**Files:**
- Modify: `data/dialogues/notes.json`
- Modify: `scripts/rooms/room_bedroom_logic.gd`

- [ ] **Step 1: Add Naayda reference to note_mother_1 in notes.json**

Find `"note_mother_1"` entry:
```json
"note_mother_1": [
    {"speaker": "Дневник", "text": "Хомус починила сегодня — Кыдаана попросила. Восьмой год ей, а пальцы уже ловкие, как у меня в её возрасте."}
],
```

Replace with:
```json
"note_mother_1": [
    {"speaker": "Дневник", "text": "Хомус починила сегодня — Кыдаана попросила. Восьмой год ей, а пальцы уже ловкие, как у меня в её возрасте."},
    {"speaker": "Дневник", "text": "Целый день играла с Наайдой у реки — домой не загнать. Вернулась мокрая, довольная, с собакой на пятках."}
],
```

- [ ] **Step 2: Update room_bedroom_logic.gd — add forward zone**

In `room_bedroom_logic.gd`, at the end of `_ready()`, add:

```gdscript
var forward_zone := get_node_or_null("ForwardZone")
if forward_zone:
	forward_zone.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and GameManager.artifacts_collected.has("doll"):
			GameManager.change_room("door_forward")
	)
```

Also add idle subtitle for second bedroom visit (player hasn't solved puzzle yet):

```gdscript
var bed := get_node_or_null("Bed")
if not bed:
	bed = get_node_or_null("Cradle")
if bed and not GameManager.artifacts_collected.has("doll"):
	bed.examined.connect(func():
		SubtitleManager.show_subtitle(
			"Здесь я видела сны. Хорошие — в начале.",
			SubtitleManager.Pos.TOP_CENTER
		)
	, CONNECT_ONE_SHOT)
```

- [ ] **Step 3: Commit**

```
git add data/dialogues/notes.json scripts/rooms/room_bedroom_logic.gd
git commit -m "feat: notes — Naayda in mother's diary; bedroom forward zone"
```

---

## Task 14: Финальная проверка навигации

- [ ] **Step 1: Run the game from main menu**

Open Godot editor. Press F5 (Run). Verify:
- Main menu loads
- "Новая игра" → starts Chapter ROAD → room_highway.tscn loads

- [ ] **Step 2: Walk through intro path**

Walk through highway → enter forest (LaikaTrigger) → Наайда appears, dialogue fires → walk to ExitZone → Chapter BALAGAN → room_entry.tscn loads ✓

- [ ] **Step 3: Test escape loop**

In room_entry, walk left into ExitZone:
- 1st attempt: silent loop to main_hall ✓
- 2nd attempt (go back to entry, exit again): subtitle "Ты не выйдешь." ✓
- 3rd attempt: subtitle "Отсюда нет выхода." ✓

- [ ] **Step 4: Walk full path**

entry → closet (subtitle on entry, kapkans subtitle) → entry2 (Наайда appears at LaikaTrigger) → main_hall (камелёк) → corridor → dining → bedroom (колыбель) → corridor2 → corridor3 → storage → kydaana_room (Наайда at bed, mirror puzzle) → entry3 → entry4 → main_hall (return subtitle "Ты дошёл.") → ritual → finale

- [ ] **Step 5: Test ritual one-attempt**

Pick up all 3 artifacts. At камелёк: place in wrong order → bad ending fires immediately. No second chance. ✓

- [ ] **Step 6: Commit verification**

```
git add .
git commit -m "test: full navigation path verified, liminal structure complete"
```
