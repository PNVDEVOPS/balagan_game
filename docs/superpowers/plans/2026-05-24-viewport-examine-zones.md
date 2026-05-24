# Viewport Fix, ExamineWindow Removal, Zone Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the camera viewport to show the full scene, remove the ExamineWindow popup system replacing it with plain dialogue, add simple window examinables in rooms, and extend + spread the Highway and Forest zones.

**Architecture:** Camera2D limit constrains scroll to scene bounds. ExamineWindow calls are replaced with `DialogueManager.show_text()` + `await DialogueManager.dialogue_finished` to preserve sequencing. Window nodes already exist in scenes — they get `examine_text` set and their old `examined` signal connections removed. Zones are extended by enlarging background rects and repositioning interactables.

**Tech Stack:** Godot 4.6, GDScript, `.tscn` scene files edited as text.

---

### Task 1: Fix Camera2D viewport limits

**Files:**
- Modify: `scenes/player/player.tscn`

- [ ] **Step 1: Set limit_bottom on Camera2D**

In `scenes/player/player.tscn`, find:
```
[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
```
Replace with:
```
[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
limit_bottom = 700
```

- [ ] **Step 2: Verify**

Run the game and enter room_highway or room_forest. Camera should now show the sky and treetops — world y=340–700 visible when player stands on ground (y=640). No black strip at the bottom.

- [ ] **Step 3: Commit**

```bash
git add scenes/player/player.tscn
git commit -m "fix: camera limit_bottom=700 — trees and sky now visible"
```

---

### Task 2: Fix room_highway_logic.gd — replace ExamineWindow with show_text

**Files:**
- Modify: `scripts/rooms/room_highway_logic.gd`

- [ ] **Step 1: Rewrite the script**

Replace the entire file content with:

```gdscript
extends Node2D

var _narrative_shown: bool = false

func _ready() -> void:
	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)

	var narrative := get_node_or_null("NarrativeTrigger")
	if narrative:
		narrative.body_entered.connect(_on_narrative_trigger)

	var phone := get_node_or_null("PhoneExamine")
	if phone:
		phone.examined.connect(_on_phone_examined)

	var hood := get_node_or_null("HoodExamine")
	if hood:
		hood.examined.connect(_on_hood_examined)

func _on_phone_examined() -> void:
	DialogueManager.show_text("", "Три деления сигнала — и вдруг ноль.\nМетель глушит всё. Никого не дозвониться.\n\nПоследнее сообщение — четыре часа назад.")

func _on_hood_examined() -> void:
	DialogueManager.show_text("", "Стрелки мёртвые. Ключ поворачивается — двигатель молчит.\n\nБатарея. Или мороз. Машину не завести.")

func _on_narrative_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _narrative_shown:
		return
	_narrative_shown = true
	DialogueManager.show_text("", "Тропа уходит в лес. Следы на снегу. Старые — но чьи?")

func _on_zone_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not Inventory.has_item("flashlight"):
		SubtitleManager.show_subtitle("Слишком темно. Хоть глаз выколи.", SubtitleManager.Pos.BOTTOM_CENTER)
		return
	GameManager.change_room("door_continue")
```

- [ ] **Step 2: Verify**

Run the game, go to room_highway. Examine the phone and dashboard — should show plain dialogue box, no popup window.

- [ ] **Step 3: Commit**

```bash
git add scripts/rooms/room_highway_logic.gd
git commit -m "refactor: highway — replace ExamineWindow with DialogueManager.show_text"
```

---

### Task 3: Fix room_forest_logic.gd — replace ExamineWindow with show_text

**Files:**
- Modify: `scripts/rooms/room_forest_logic.gd`

- [ ] **Step 1: Replace _on_murder_site_examined**

Find the function:
```gdscript
func _on_murder_site_examined() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Амулет шамана",
		"Птичьи кости, нанизанные на истлевшую нить. Давно. Кора дерева вросла в узел — значит, висит годами.\n\nТакое оставляют не как подношение. Как замок. Чтобы что-то не ушло с этого места.",
		Color(0.04, 0.03, 0.02, 1.0)
	)
```

Replace with:
```gdscript
func _on_murder_site_examined() -> void:
	DialogueManager.show_text("", "Птичьи кости, нанизанные на истлевшую нить. Давно. Кора дерева вросла в узел — значит, висит годами.\n\nТакое оставляют не как подношение. Как замок. Чтобы что-то не ушло с этого места.")
```

- [ ] **Step 2: Verify**

Run the game, go to room_forest. Examine the ShamanAmulet — should show plain dialogue, no popup.

- [ ] **Step 3: Commit**

```bash
git add scripts/rooms/room_forest_logic.gd
git commit -m "refactor: forest — replace ExamineWindow with show_text"
```

---

### Task 4: Fix room_closet_logic.gd — replace ExamineWindow with show_text

**Files:**
- Modify: `scripts/rooms/room_closet_logic.gd`

- [ ] **Step 1: Replace shelves inline lambda**

Find:
```gdscript
	var shelves := get_node_or_null("ShelvesExamine")
	if shelves:
		shelves.examined.connect(func():
			var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
			get_tree().current_scene.add_child(ew)
			ew.open(
				"Полка",
				"Банки с припасами. Большинство пустые. Одна треснула — содержимое давно высохло.\n\nНа самой верхней — охотничий нож в потёртых ножнах. Чистый.",
				Color(0.04, 0.03, 0.02, 1.0)
			)
		)
```

Replace with:
```gdscript
	var shelves := get_node_or_null("ShelvesExamine")
	if shelves:
		shelves.examined.connect(func():
			DialogueManager.show_text("", "Банки с припасами. Большинство пустые. Одна треснула — содержимое давно высохло.\n\nНа самой верхней — охотничий нож в потёртых ножнах. Чистый.")
		)
```

- [ ] **Step 2: Verify**

Run the game, navigate to room_closet. Examine the shelves — plain dialogue, no popup.

- [ ] **Step 3: Commit**

```bash
git add scripts/rooms/room_closet_logic.gd
git commit -m "refactor: closet — replace ExamineWindow with show_text"
```

---

### Task 5: Fix room_corridor_logic.gd and room_dining_logic.gd — remove jumpscare windows

**Files:**
- Modify: `scripts/rooms/room_corridor_logic.gd`
- Modify: `scripts/rooms/room_dining_logic.gd`

- [ ] **Step 1: Fix corridor — remove WindowExamine connection**

In `scripts/rooms/room_corridor_logic.gd`, find and **delete** the entire window block:
```gdscript
	var window := get_node_or_null("WindowExamine")
	if window:
		window.examined.connect(func():
			var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
			get_tree().current_scene.add_child(ew)
			ew.open_jumpscare(
				"Окно",
				"Коридор выходит на двор. За стеклом — темнота и снег.\n\nТы смотришь. Темнота смотрит обратно.",
				Color(0.02, 0.02, 0.04, 1.0)
			)
		)
```

The `WindowExamine` node will get its `examine_text` set in Task 7, so the examinable handles it automatically.

- [ ] **Step 2: Fix dining — remove two WindowExamine and table connections**

In `scripts/rooms/room_dining_logic.gd`:

Find and **delete** the window block:
```gdscript
	var window := get_node_or_null("WindowExamine")
	if window:
		window.examined.connect(func():
			var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
			get_tree().current_scene.add_child(ew)
			ew.open_jumpscare(
				"Окно",
				"Стекло заиндевело. Сквозь него — только метель и темнота.\n\nНичего не видно. Почти ничего.",
				Color(0.02, 0.03, 0.07, 1.0)
			)
		)
```

Find and replace the table block (preserves sequenced dialogue):
```gdscript
	var table := get_node_or_null("TableExaminable")
	if table:
		table.examined.connect(func():
			var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
			get_tree().current_scene.add_child(ew)
			ew.open(
				"Стол",
				"Тарелки на двоих. Еда остыла, но не заветрела — ушли недавно. Или не ушли.\n\nЧашка у края стола перевёрнута. Чай разлился и высох.",
				Color(0.06, 0.04, 0.03, 1.0)
			)
			await ew.window_closed
			GameManager.mark_note_found("note_mother_2")
			DialogueManager.start_dialogue("notes/note_mother_2")
		)
```

Replace with:
```gdscript
	var table := get_node_or_null("TableExaminable")
	if table:
		table.examined.connect(func():
			DialogueManager.show_text("", "Тарелки на двоих. Еда остыла, но не заветрела — ушли недавно. Или не ушли.\n\nЧашка у края стола перевёрнута. Чай разлился и высох.")
			await DialogueManager.dialogue_finished
			GameManager.mark_note_found("note_mother_2")
			DialogueManager.start_dialogue("notes/note_mother_2")
		)
```

- [ ] **Step 3: Verify**

Run the game, enter corridor and dining rooms. Examine window in each → plain dialogue from examine_text (set in next task). Table in dining → text, then note dialogue.

- [ ] **Step 4: Commit**

```bash
git add scripts/rooms/room_corridor_logic.gd scripts/rooms/room_dining_logic.gd
git commit -m "refactor: corridor + dining — remove jumpscare windows, fix table sequence"
```

---

### Task 6: Fix room_bedroom_logic.gd — remove ExamineWindow, remove FamilyPhoto

**Files:**
- Modify: `scripts/rooms/room_bedroom_logic.gd`

- [ ] **Step 1: Remove FamilyPhoto connection (lines 6-8)**

Find and **delete**:
```gdscript
	var photo := get_node_or_null("FamilyPhoto")
	if photo:
		photo.examined.connect(_on_family_photo_examined, CONNECT_ONE_SHOT)
```

- [ ] **Step 2: Remove WindowExamine connection**

Find and **delete** the window block (lines 10-12 after removal above):
```gdscript
	var window := get_node_or_null("WindowExamine")
	if window:
		window.examined.connect(_on_window_examined, CONNECT_ONE_SHOT)
```

- [ ] **Step 3: Replace _on_window_examined function**

Find and **delete** the entire function:
```gdscript
func _on_window_examined() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open_jumpscare(
		"Окно",
		"За окном — метель. Темно. Ничего не видно дальше двух шагов.\n\nТы смотришь в темноту.",
		Color(0.02, 0.03, 0.06, 1.0)
	)
```

- [ ] **Step 4: Replace _on_cradle_examined — remove ExamineWindow, preserve flow**

Find:
```gdscript
func _on_cradle_examined() -> void:
	if _cradle_minigame_active:
		return
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Колыбель",
		"Деревянная, потёртая. Качается от малейшего движения воздуха.\n\nПолог из выцветшей ткани. Над ней — что-то нацарапано на бревне.",
		Color(0.07, 0.04, 0.05, 1.0)
	)
	await ew.window_closed
	if _cradle_minigame_active:
		return
	DialogueManager.show_text("", "Загадка нацарапана над колыбелью.")
	await DialogueManager.dialogue_finished
	DialogueManager.start_dialogue("notes/riddle_cradle")
	await DialogueManager.dialogue_finished
	_launch_cradle_minigame()
```

Replace with:
```gdscript
func _on_cradle_examined() -> void:
	if _cradle_minigame_active:
		return
	DialogueManager.show_text("", "Деревянная, потёртая. Качается от малейшего движения воздуха.\n\nПолог из выцветшей ткани. Над ней — что-то нацарапано на бревне.")
	await DialogueManager.dialogue_finished
	if _cradle_minigame_active:
		return
	DialogueManager.start_dialogue("notes/riddle_cradle")
	await DialogueManager.dialogue_finished
	_launch_cradle_minigame()
```

- [ ] **Step 5: Replace _on_chest_used — preserve doll reveal sequence**

Find:
```gdscript
func _on_chest_used() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Сундук",
		"Внутри — тряпичная кукла в старом шёлке. Маленькая. Одно ухо надорвано.\n\nЧья-то. Давно.",
		Color(0.06, 0.04, 0.03, 1.0)
	)
	await ew.window_closed
	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.visible = true
		doll.set_deferred("monitoring", true)
```

Replace with:
```gdscript
func _on_chest_used() -> void:
	DialogueManager.show_text("", "Внутри — тряпичная кукла в старом шёлке. Маленькая. Одно ухо надорвано.\n\nЧья-то. Давно.")
	await DialogueManager.dialogue_finished
	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.visible = true
		doll.set_deferred("monitoring", true)
```

- [ ] **Step 6: Delete _on_family_photo_examined function**

Find and **delete** the entire function at the end of the file:
```gdscript
func _on_family_photo_examined() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Семейное фото",
		"Чёрно-белое. Мужчина и женщина — нарядные. Рядом — дети, двое.\n\nОни смотрят прямо в объектив. Не улыбаются — так было принято.\n\nНа обороте карандашом: «1913».",
		Color(0.04, 0.03, 0.02, 1.0)
	)
```

- [ ] **Step 7: Verify**

Run the game, enter bedroom. Cradle → description text, then riddle, then minigame. Chest → description then doll appears. No FamilyPhoto interaction.

- [ ] **Step 8: Commit**

```bash
git add scripts/rooms/room_bedroom_logic.gd
git commit -m "refactor: bedroom — remove ExamineWindow + FamilyPhoto, fix cradle/chest sequence"
```

---

### Task 7: Fix room_kydaana_logic.gd — replace kamylok + chest ExamineWindow

**Files:**
- Modify: `scripts/rooms/room_kydaana_logic.gd`

- [ ] **Step 1: Replace _on_kamylok_examined**

Find the entire function:
```gdscript
func _on_kamylok_examined() -> void:
	if kamylok_state == KamylokState.RITUAL_ACTIVE:
		_place_ritual_artifact()
		return

	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	match kamylok_state:
		KamylokState.COLD:
			ew.open(
				"Камелёк",
				"Железная печь с чугунным поддувалом. Угли холодные — давно не топили.\n\nВнешняя сторона кована якутским узором. Тонкая работа, старая.",
				Color(0.05, 0.03, 0.02, 1.0)
			)
		KamylokState.BURNING:
			ew.open(
				"Камелёк",
				"Огонь горит ровно, жарко. Среди угля — что-то поблёскивает.",
				Color(0.18, 0.08, 0.02, 1.0)
			)
		KamylokState.RITUAL_READY:
			ew.open(
				"Камелёк",
				"Пламя стало другим — тихое, почти прозрачное. Ждёт даров.",
				Color(0.16, 0.06, 0.02, 1.0)
			)
	await ew.window_closed
	match kamylok_state:
		KamylokState.COLD:
			if Inventory.has_item("firewood"):
				Inventory.remove_item("firewood")
				kamylok_state = KamylokState.BURNING
				_fire_lit()
			else:
				DialogueManager.show_text("", "Камелёк потух. Угли холодные. Нужно чем-то разжечь.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно. Среди углей что-то поблёскивает.")
		KamylokState.RITUAL_READY:
			kamylok_state = KamylokState.RITUAL_ACTIVE
			DialogueManager.show_text("", "Пламя ждёт.")
```

Replace with:
```gdscript
func _on_kamylok_examined() -> void:
	if kamylok_state == KamylokState.RITUAL_ACTIVE:
		_place_ritual_artifact()
		return
	match kamylok_state:
		KamylokState.COLD:
			DialogueManager.show_text("", "Железная печь с чугунным поддувалом. Угли холодные — давно не топили.\n\nВнешняя сторона кована якутским узором. Тонкая работа, старая.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно, жарко. Среди угля — что-то поблёскивает.")
		KamylokState.RITUAL_READY:
			DialogueManager.show_text("", "Пламя стало другим — тихое, почти прозрачное. Ждёт даров.")
	await DialogueManager.dialogue_finished
	match kamylok_state:
		KamylokState.COLD:
			if Inventory.has_item("firewood"):
				Inventory.remove_item("firewood")
				kamylok_state = KamylokState.BURNING
				_fire_lit()
			else:
				DialogueManager.show_text("", "Камелёк потух. Угли холодные. Нужно чем-то разжечь.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно. Среди углей что-то поблёскивает.")
		KamylokState.RITUAL_READY:
			kamylok_state = KamylokState.RITUAL_ACTIVE
			DialogueManager.show_text("", "Пламя ждёт.")
```

- [ ] **Step 2: Replace _on_chest_used**

Find:
```gdscript
func _on_chest_used() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Сундук",
		"Внутри — что-то завёрнуто в старую кожу. Тяжёлое. Тёплое на ощупь.\n\nПтичьи кости на нити. Старый. Очень старый.",
		Color(0.06, 0.04, 0.02, 1.0)
	)
	await ew.window_closed
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)
```

Replace with:
```gdscript
func _on_chest_used() -> void:
	DialogueManager.show_text("", "Внутри — что-то завёрнуто в старую кожу. Тяжёлое. Тёплое на ощупь.\n\nПтичьи кости на нити. Старый. Очень старый.")
	await DialogueManager.dialogue_finished
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)
```

- [ ] **Step 3: Verify**

Run the game, go to the Balagan (kydaana room). Examine kamylok in each state — plain dialogue then correct action. Chest → text then amulet appears.

- [ ] **Step 4: Commit**

```bash
git add scripts/rooms/room_kydaana_logic.gd
git commit -m "refactor: kydaana — replace ExamineWindow in kamylok + chest"
```

---

### Task 8: Fix room_main_hall_logic.gd — replace mirror + floorboard ExamineWindow

**Files:**
- Modify: `scripts/rooms/room_main_hall_logic.gd`

- [ ] **Step 1: Replace _on_mirror_examined**

Find:
```gdscript
func _on_mirror_examined() -> void:
	if _mirror_minigame_active:
		return
	if _mirror_solved:
		DialogueManager.show_text("", "Зеркало собрано. В нём — отражение комнаты. Там, где сучок в доске похож на звезду, что-то спрятано.")
		return
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Старое зеркало",
		"Деревянная рама, потемневшая от времени. Якутская резьба по краю.\n\nСтекло разбито — три крупных осколка. На одном что-то нацарапано.",
		Color(0.04, 0.04, 0.06, 1.0)
	)
	await ew.window_closed
	if _mirror_minigame_active:
		return
	SubtitleManager.show_subtitle(
		"Оно разбилось в ту ночь. Я не смотрелась с тех пор.",
		SubtitleManager.Pos.MID_LEFT
	)
	DialogueManager.start_dialogue("notes/riddle_mirror")
	await DialogueManager.dialogue_finished
	_launch_mirror_minigame()
```

Replace with:
```gdscript
func _on_mirror_examined() -> void:
	if _mirror_minigame_active:
		return
	if _mirror_solved:
		DialogueManager.show_text("", "Зеркало собрано. В нём — отражение комнаты. Там, где сучок в доске похож на звезду, что-то спрятано.")
		return
	DialogueManager.show_text("", "Деревянная рама, потемневшая от времени. Якутская резьба по краю.\n\nСтекло разбито — три крупных осколка. На одном что-то нацарапано.")
	await DialogueManager.dialogue_finished
	if _mirror_minigame_active:
		return
	SubtitleManager.show_subtitle(
		"Оно разбилось в ту ночь. Я не смотрелась с тех пор.",
		SubtitleManager.Pos.MID_LEFT
	)
	DialogueManager.start_dialogue("notes/riddle_mirror")
	await DialogueManager.dialogue_finished
	_launch_mirror_minigame()
```

- [ ] **Step 2: Replace _on_floorboard_examined**

Find:
```gdscript
func _on_floorboard_examined() -> void:
	var ew := preload("res://scenes/ui/examine_window.tscn").instantiate()
	get_tree().current_scene.add_child(ew)
	ew.open(
		"Половица",
		"Одна доска — чуть темнее других. Сучок посередине похож на звезду.\n\nПод ней — пустота. Что-то спрятали давно.",
		Color(0.05, 0.04, 0.03, 1.0)
	)
	await ew.window_closed
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)
```

Replace with:
```gdscript
func _on_floorboard_examined() -> void:
	DialogueManager.show_text("", "Одна доска — чуть темнее других. Сучок посередине похож на звезду.\n\nПод ней — пустота. Что-то спрятали давно.")
	await DialogueManager.dialogue_finished
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)
```

- [ ] **Step 3: Verify**

Run the game, go to main_hall (Kydaana's room). Examine mirror → description text, then subtitle, then riddle, then minigame launches. Floorboard → text then earring appears.

- [ ] **Step 4: Commit**

```bash
git add scripts/rooms/room_main_hall_logic.gd
git commit -m "refactor: main_hall — replace ExamineWindow in mirror + floorboard"
```

---

### Task 9: Add examine_text to window nodes in scenes + add entry window + remove FamilyPhoto

**Files:**
- Modify: `scenes/rooms/room_bedroom.tscn`
- Modify: `scenes/rooms/room_corridor.tscn`
- Modify: `scenes/rooms/room_dining.tscn`
- Modify: `scenes/rooms/room_entry.tscn`

- [ ] **Step 1: Bedroom — set WindowExamine text and remove FamilyPhoto node**

In `scenes/rooms/room_bedroom.tscn`, find:
```
[node name="WindowExamine" parent="." instance=ExtResource("7")]
position = Vector2(300, 560)
examine_text = ""
```
Replace with:
```
[node name="WindowExamine" parent="." instance=ExtResource("7")]
position = Vector2(300, 560)
examine_text = "За окном — метель. Деревья согнулись под снегом. Как мы выберемся отсюда?"
```

Also find and **delete** the FamilyPhoto node entirely:
```
[node name="FamilyPhoto" parent="." instance=ExtResource("7")]
position = Vector2(700, 620)
interaction_text = "Посмотреть"
```

- [ ] **Step 2: Corridor — set WindowExamine text**

In `scenes/rooms/room_corridor.tscn`, find:
```
[node name="WindowExamine" parent="." instance=ExtResource("4_exam")]
position = Vector2(160, 200)
interaction_text = "Посмотреть в окно"
```
Replace with:
```
[node name="WindowExamine" parent="." instance=ExtResource("4_exam")]
position = Vector2(160, 200)
interaction_text = "Посмотреть в окно"
examine_text = "Черно. Только снег мельтешит в свете луны. Тихо, как будто мир снаружи вымер."
```

- [ ] **Step 3: Dining — set WindowExamine text**

In `scenes/rooms/room_dining.tscn`, find:
```
[node name="WindowExamine" parent="." instance=ExtResource("2_exam")]
position = Vector2(140, 200)
interaction_text = "Посмотреть в окно"
```
Replace with:
```
[node name="WindowExamine" parent="." instance=ExtResource("2_exam")]
position = Vector2(140, 200)
interaction_text = "Посмотреть в окно"
examine_text = "Двор занесло. Забор накренился под снегом. Следы у крыльца — старые."
```

- [ ] **Step 4: Entry — add WindowEntry node**

In `scenes/rooms/room_entry.tscn`, after the `ClothesExaminable` node, add:
```
[node name="WindowEntry" parent="." instance=ExtResource("3_exam")]
position = Vector2(500, 200)
interaction_text = "Посмотреть в окно"
examine_text = "Дорога едва видна под снегом. Следы уже замело. Обратного пути нет."
```

- [ ] **Step 5: Verify**

Run the game. Check each room:
- Bedroom window → "За окном — метель..." dialogue. No FamilyPhoto interaction.
- Corridor window → "Черно..." dialogue.
- Dining window → "Двор занесло..." dialogue.
- Entry window (right side) → "Дорога едва видна..." dialogue.

- [ ] **Step 6: Commit**

```bash
git add scenes/rooms/room_bedroom.tscn scenes/rooms/room_corridor.tscn scenes/rooms/room_dining.tscn scenes/rooms/room_entry.tscn
git commit -m "feat: simple window examinables in bedroom/corridor/dining/entry + remove FamilyPhoto"
```

---

### Task 10: Delete examine_window files

**Files:**
- Delete: `scenes/ui/examine_window.tscn`
- Delete: `scripts/ui/examine_window.gd`

- [ ] **Step 1: Verify no remaining references**

Run:
```bash
grep -r "examine_window" scripts/ scenes/ --include="*.gd" --include="*.tscn"
```
Expected: no output (no remaining references).

- [ ] **Step 2: Delete the files**

```bash
git rm scenes/ui/examine_window.tscn scripts/ui/examine_window.gd
```

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: delete examine_window system — fully replaced by DialogueManager"
```

---

### Task 11: Polish Highway scene — extend to 2400px and spread interactables

**Files:**
- Modify: `scenes/rooms/room_highway.tscn`

- [ ] **Step 1: Extend background and road surfaces**

In `scenes/rooms/room_highway.tscn`:

Change `Background`:
```
[node name="Background" type="ColorRect" parent="." unique_id=1808281662]
offset_right = 1800.0
```
→
```
[node name="Background" type="ColorRect" parent="." unique_id=1808281662]
offset_right = 2400.0
```

Change `RoadSurface`:
```
[node name="RoadSurface" type="ColorRect" parent="." unique_id=1295526964]
offset_left = -2.0
offset_top = 561.0
offset_right = 1798.0
offset_bottom = 661.0
```
→
```
[node name="RoadSurface" type="ColorRect" parent="." unique_id=1295526964]
offset_left = -2.0
offset_top = 561.0
offset_right = 2398.0
offset_bottom = 661.0
```

Change `FloorVisual`:
```
[node name="FloorVisual" type="ColorRect" parent="." unique_id=856822761]
offset_top = 660.0
offset_right = 1800.0
offset_bottom = 700.0
```
→
```
[node name="FloorVisual" type="ColorRect" parent="." unique_id=856822761]
offset_top = 660.0
offset_right = 2400.0
offset_bottom = 700.0
```

- [ ] **Step 2: Add road dashes and trees in new space**

After the existing `CenterLineDash6` node, add:
```
[node name="CenterLineDash7" type="ColorRect" parent="." unique_id=1735695514]
offset_left = 1821.0
offset_top = 596.0
offset_right = 1881.0
offset_bottom = 600.0
color = Color(0.8, 0.8, 0.7, 0.6)

[node name="CenterLineDash8" type="ColorRect" parent="." unique_id=1735695515]
offset_left = 2121.0
offset_top = 596.0
offset_right = 2181.0
offset_bottom = 600.0
color = Color(0.8, 0.8, 0.7, 0.6)
```

After the existing `TreeRight5` node, add:
```
[node name="TreeRight6" type="ColorRect" parent="." unique_id=900626160]
offset_left = 1921.0
offset_top = 373.0
offset_right = 1953.0
offset_bottom = 608.0
color = Color(0.04, 0.07, 0.03, 1)

[node name="TreeRight7" type="ColorRect" parent="." unique_id=900626161]
offset_left = 2221.0
offset_top = 353.0
offset_right = 2257.0
offset_bottom = 608.0
color = Color(0.03, 0.06, 0.02, 1)
```

- [ ] **Step 3: Reposition SnowSign, NarrativeTrigger, TriggerZone, RoomRight**

Change `SnowSign` position:
```
[node name="SnowSign" parent="." unique_id=1658671472 instance=ExtResource("4")]
position = Vector2(900, 640)
```
→
```
[node name="SnowSign" parent="." unique_id=1658671472 instance=ExtResource("4")]
position = Vector2(1400, 640)
```

Change `NarrativeTrigger` position:
```
[node name="NarrativeTrigger" type="Area2D" parent="." unique_id=671234501]
position = Vector2(1400, 350)
```
→
```
[node name="NarrativeTrigger" type="Area2D" parent="." unique_id=671234501]
position = Vector2(1800, 350)
```

Change `TriggerZone` position:
```
[node name="TriggerZone" type="Area2D" parent="." unique_id=534517377]
position = Vector2(1770, 350)
```
→
```
[node name="TriggerZone" type="Area2D" parent="." unique_id=534517377]
position = Vector2(2370, 350)
```

Change `RoomRight` marker:
```
[node name="RoomRight" type="Marker2D" parent="." unique_id=919411197]
position = Vector2(1800, 180)
```
→
```
[node name="RoomRight" type="Marker2D" parent="." unique_id=919411197]
position = Vector2(2400, 180)
```

- [ ] **Step 4: Verify**

Run the game. Enter room_highway. Walk right — road should extend ~600px further than before. Narrative text triggers further along. TriggerZone (forest entrance gate) is at the new far end.

- [ ] **Step 5: Commit**

```bash
git add scenes/rooms/room_highway.tscn
git commit -m "feat: extend highway to 2400px, spread SnowSign/triggers, add trees + road dashes"
```

---

### Task 12: Polish Forest scene — extend to 3200px and spread notes/Balagan

**Files:**
- Modify: `scenes/rooms/room_forest.tscn`

- [ ] **Step 1: Extend background, ground, floor, and path light**

Change `Background`:
```
offset_right = 2400.0
```
→
```
offset_right = 3200.0
```

Change `SnowGround`:
```
[node name="SnowGround" type="ColorRect" parent="." unique_id=612901465]
offset_top = 650.0
offset_right = 2400.0
```
→
```
[node name="SnowGround" type="ColorRect" parent="." unique_id=612901465]
offset_top = 650.0
offset_right = 3200.0
```

Change `FloorVisual`:
```
[node name="FloorVisual" type="ColorRect" parent="." unique_id=785561926]
offset_top = 660.0
offset_right = 2400.0
```
→
```
[node name="FloorVisual" type="ColorRect" parent="." unique_id=785561926]
offset_top = 660.0
offset_right = 3200.0
```

Change `PathLight`:
```
[node name="PathLight" type="ColorRect" parent="." unique_id=1650312362]
offset_left = 12.0
offset_top = 610.0
offset_right = 2212.0
```
→
```
[node name="PathLight" type="ColorRect" parent="." unique_id=1650312362]
offset_left = 12.0
offset_top = 610.0
offset_right = 3012.0
```

- [ ] **Step 2: Add two more trees in the new space**

After the existing `Canopy10` node, add:
```
[node name="Trunk11" type="ColorRect" parent="." unique_id=809598978]
offset_left = 2300.0
offset_top = 302.0
offset_right = 2330.0
offset_bottom = 650.0
color = Color(0.04, 0.03, 0.02, 1)

[node name="Canopy11" type="ColorRect" parent="." unique_id=1691691472]
offset_left = 2272.0
offset_top = 284.0
offset_right = 2358.0
offset_bottom = 364.0
color = Color(0.03, 0.07, 0.02, 1)

[node name="Trunk12" type="ColorRect" parent="." unique_id=809598979]
offset_left = 2680.0
offset_top = 296.0
offset_right = 2710.0
offset_bottom = 648.0
color = Color(0.05, 0.04, 0.03, 1)

[node name="Canopy12" type="ColorRect" parent="." unique_id=1691691473]
offset_left = 2652.0
offset_top = 278.0
offset_right = 2738.0
offset_bottom = 358.0
color = Color(0.02, 0.06, 0.01, 1)
```

- [ ] **Step 3: Spread notes and interactables**

Change positions (find each by node name, update only the `position =` line):

| Node | From | To |
|------|------|----|
| NoteForestFather | `Vector2(500, 620)` | `Vector2(600, 620)` |
| BrokenBranch | `Vector2(700, 660)` | `Vector2(950, 660)` |
| NoteAiyyna2 | `Vector2(1000, 620)` | `Vector2(1300, 620)` |
| OldFireplace | `Vector2(1200, 660)` | `Vector2(1700, 660)` |
| NoteFatherLast | `Vector2(1500, 620)` | `Vector2(2100, 620)` |
| ShamanAmulet | `Vector2(1800, 660)` | `Vector2(2500, 660)` |
| BalaganSign | `Vector2(2100, 660)` | `Vector2(2900, 660)` |
| LaikaTrigger | `Vector2(1460, 350)` | `Vector2(2000, 350)` |
| Laika | `Vector2(1600, 648)` | `Vector2(2150, 648)` |
| ExitZone | `Vector2(2330, 350)` | `Vector2(3130, 350)` |
| RoomRight | `Vector2(2400, 180)` | `Vector2(3200, 180)` |

- [ ] **Step 4: Move Balagan building (silhouette + roof + light)**

Change `BalaganSilhouette`:
```
[node name="BalaganSilhouette" type="ColorRect" parent="." unique_id=862367796]
offset_left = 2196.0
offset_top = 448.0
offset_right = 2376.0
offset_bottom = 648.0
```
→
```
[node name="BalaganSilhouette" type="ColorRect" parent="." unique_id=862367796]
offset_left = 2880.0
offset_top = 448.0
offset_right = 3060.0
offset_bottom = 648.0
```

Change `BalaganRoof`:
```
[node name="BalaganRoof" type="ColorRect" parent="." unique_id=156762754]
offset_left = 2176.0
offset_top = 408.0
offset_right = 2396.0
offset_bottom = 458.0
```
→
```
[node name="BalaganRoof" type="ColorRect" parent="." unique_id=156762754]
offset_left = 2860.0
offset_top = 408.0
offset_right = 3080.0
offset_bottom = 458.0
```

Change `BalaganLight`:
```
[node name="BalaganLight" type="ColorRect" parent="." unique_id=186962074]
offset_left = 2256.0
offset_top = 502.0
offset_right = 2296.0
offset_bottom = 562.0
```
→
```
[node name="BalaganLight" type="ColorRect" parent="." unique_id=186962074]
offset_left = 2940.0
offset_top = 502.0
offset_right = 2980.0
offset_bottom = 562.0
```

- [ ] **Step 5: Verify**

Run the game. Enter room_forest. Walk through the path — notes should be spaced ~400px apart. Laika encounter at ~x=2000. Balagan visible at the far right end (~x=2900). Exit zone at x=3130.

- [ ] **Step 6: Commit**

```bash
git add scenes/rooms/room_forest.tscn
git commit -m "feat: extend forest to 3200px, spread notes + Balagan, add trees"
```

---

### Task 13: Update memory

- [ ] **Step 1: Update project_backlog.md**

Update `C:\Users\gugom\.claude\projects\C--Users-gugom-OneDrive--------------Godot-game\memory\project_backlog.md` to reflect completed work and remove stale entries.

---

## Spec coverage check

| Spec requirement | Task |
|-----------------|------|
| Viewport: Camera2D limit_bottom=700 | Task 1 |
| Remove ExamineWindow — highway | Task 2 |
| Remove ExamineWindow — forest | Task 3 |
| Remove ExamineWindow — closet | Task 4 |
| Remove ExamineWindow — corridor/dining + fix table | Task 5 |
| Remove ExamineWindow — bedroom + remove FamilyPhoto handler | Task 6 |
| Remove ExamineWindow — kydaana (kamylok, chest) | Task 7 |
| Remove ExamineWindow — main_hall (mirror, floorboard) | Task 8 |
| Set examine_text on window nodes + add entry window + delete FamilyPhoto scene node | Task 9 |
| Delete examine_window files | Task 10 |
| Highway: extend to 2400px, spread interactables | Task 11 |
| Forest: extend to 3200px, spread notes + Balagan | Task 12 |
