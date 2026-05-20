# Балаган: полная реализация — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Превратить прототип в законченную игру: PT-петля, три загадки с артефактами, ритуал с двумя концовками, записки на якутском фольклоре.

**Architecture:** Все новые механики встраиваются в существующие системы (GameManager, DialogueManager, Inventory, examinable/usable/pickable). Добавляются `loop_state` и `ritual_result` в GameManager. Каждая комната управляется своим room_*_logic.gd. Данные записок — в data/dialogues/notes.json.

**Tech Stack:** GDScript 4, Godot 4.3+, JSON-диалоги, Area2D interactables, signal-based decoupling.

---

## Карта файлов

| Действие | Файл |
|---|---|
| Modify | `scripts/player/player.gd` |
| Modify | `scripts/autoload/game_manager.gd` |
| Create | `data/dialogues/notes.json` |
| Create | `data/dialogues/finale.json` |
| Create | `scripts/rooms/room_entrance_logic.gd` |
| Modify | `scenes/rooms/room_entrance.tscn` |
| Modify | `scenes/rooms/room_main_hall.tscn` |
| Modify | `scripts/rooms/room_main_hall_logic.gd` |
| Modify | `scenes/rooms/room_bedroom.tscn` |
| Modify | `scripts/rooms/room_bedroom_logic.gd` |
| Modify | `scenes/rooms/room_basement.tscn` |
| Modify | `scripts/rooms/room_basement_logic.gd` |
| Modify | `scenes/rooms/room_storage.tscn` |
| Modify | `scripts/rooms/room_storage_logic.gd` |
| Modify | `scenes/rooms/room_highway.tscn` |
| Modify | `scripts/rooms/room_highway_logic.gd` |
| Modify | `scenes/rooms/room_forest.tscn` |
| Modify | `scripts/rooms/room_forest_logic.gd` |
| Modify | `scripts/rooms/finale.gd` |
| Modify | All `scenes/rooms/*.tscn` — room height 360→700 |
| Modify | `scripts/autoload/game_manager.gd` — dynamic camera bottom |

---

## Task 1: Fix door interaction (collide_with_areas)

**Files:**
- Modify: `scripts/player/player.gd:19-21`

**Problem:** `RayCast2D` в Godot 4 не видит `Area2D` при `collide_with_areas = false` (по умолчанию). Все интерактивные объекты — Area2D. Игрок не может нажать E у двери.

- [ ] **Step 1: Add collide_with_areas to _ready()**

В `player.gd` изменить `_ready()`:

```gdscript
func _ready() -> void:
    ray.collide_with_areas = true
    prompt.visible = false
    flashlight_ctrl.set_facing(true)
```

- [ ] **Step 2: Verify**

Запустить игру → зайти в комнату с дверью → подойти к двери → проверить, что появляется подсказка взаимодействия (Sprite2D prompt) → нажать E → должен произойти переход в комнату.

- [ ] **Step 3: Commit**

```
git add scripts/player/player.gd
git commit -m "fix: enable RayCast2D collide_with_areas for Area2D door detection"
```

---

## Task 2: GameManager — loop_state, ritual_result, start_finale, новые artifact IDs

**Files:**
- Modify: `scripts/autoload/game_manager.gd`

- [ ] **Step 1: Add new variables and update _apply_artifact_graph_mutation**

Заменить весь файл на следующий (все оригинальные функции сохранены, изменены: добавлены переменные, упрощена _apply_artifact_graph_mutation, добавлен start_finale, обновлён restore_from_save):

```gdscript
extends Node

signal room_changed(room_id: String)
signal artifact_collected(artifact_id: String)

var current_room: String = "main_hall"
var artifacts_collected: Array[String] = []
var room_graph: Dictionary = {}
var transition_count: int = 0
var is_transitioning: bool = false
var spawn_door_id: String = ""
var loop_state: int = 0
var ritual_result: String = ""

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

func start_finale(result: String) -> void:
	ritual_result = result
	SaveManager.autosave()
	is_transitioning = true
	_ensure_fade()
	await _screen_fade.fade_out(0.8)
	current_room = "finale"
	get_tree().change_scene_to_file("res://scenes/rooms/room_finale.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_fade()
	await _screen_fade.fade_in(0.5)
	is_transitioning = false

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
		var room_bottom := get_tree().current_scene.get_node_or_null("RoomBottom")
		var bottom_limit: int = int(room_bottom.global_position.y) if room_bottom else 700
		camera.limit_left = 0
		camera.limit_right = right_limit
		camera.limit_top = 0
		camera.limit_bottom = bottom_limit

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
	loop_state = artifacts_collected.size()
	SaveManager.autosave()

func restore_from_save() -> void:
	_load_room_graph()
	loop_state = artifacts_collected.size()

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

- [ ] **Step 2: Verify**

Запустить → открыть отладочную консоль → убедиться что GameManager стартует без ошибок, переменные `loop_state` и `ritual_result` присутствуют.

- [ ] **Step 3: Commit**

```
git add scripts/autoload/game_manager.gd
git commit -m "feat: add loop_state, ritual_result, start_finale to GameManager"
```

---

## Task 3: Создать data/dialogues/notes.json и data/dialogues/finale.json

**Files:**
- Create: `data/dialogues/notes.json`
- Create: `data/dialogues/finale.json`

- [ ] **Step 1: Create notes.json**

Создать файл `data/dialogues/notes.json`:

```json
{
  "note_aiyyna_1": [
    {"speaker": "Записка", "text": "Постучали поздно. За дверью стоял старик в драном тарбагане, борода в инее. Просил ночлега."},
    {"speaker": "Записка", "text": "Отец сказал: «Иди в улус, у нас лишних шкур нет». Старик не ответил. Только посмотрел — долго, прямо в глаза отцу. И ушёл в метель."},
    {"speaker": "Записка", "text": "Мать после этого три ночи не спала. Говорила — нельзя было отказывать. Я тогда не поняла, о чём она."}
  ],
  "note_aiyyna_2": [
    {"speaker": "Записка", "text": "Они ушли вдвоём на рассвете. Отец и Ньургун. Я давала им хлеб в дорогу — Ньургун улыбнулся, сказал: «К вечеру вернёмся, заплету тебе косу заново»."},
    {"speaker": "Записка", "text": "Отец вернулся один. Сказал — медведь. Сказал — несчастный случай."},
    {"speaker": "Записка", "text": "Но я видела его руки. На них не было крови медведя. Я знаю, какая она."}
  ],
  "note_aiyyna_3": [
    {"speaker": "Записка", "text": "Мать слегла после первого снега. Шаман из соседнего улуса приехал, посмотрел, ничего не сказал. Только собрал свои бубны и уехал быстрее, чем приехал."},
    {"speaker": "Записка", "text": "Она угасала тихо. Перед смертью взяла мою руку и прошептала: «Это всё за ту ночь, доченька. За того старика. Прости меня, что не настояла»."},
    {"speaker": "Записка", "text": "Я не поняла. Тогда — ещё не поняла."}
  ],
  "note_aiyyna_4": [
    {"speaker": "Записка", "text": "Отец вырастил его из телёнка. Кормил с руки. Назвал — Хара."},
    {"speaker": "Записка", "text": "Я смотрела в окно, когда это случилось. Хара ждал его у изгороди. Спокойно ждал. А потом — будто кто-то шепнул быку на ухо."},
    {"speaker": "Записка", "text": "Я выбежала, но было поздно. Снег под отцом был красным до самой изгороди. Лайка выла всю ночь. Я не могла плакать."}
  ],
  "note_aiyyna_5": [
    {"speaker": "Записка", "text": "Я осталась одна. Лайка не отходит от меня. Дом стал тихим — даже ветер обходит его стороной, будто боится."},
    {"speaker": "Записка", "text": "Я больше не выхожу за порог. Незачем. Если кто-то найдёт это — знай: я не больна. Я просто устала ждать, когда меня заберут следом."},
    {"speaker": "Записка", "text": "Бабка моя говорила — душа уходит туда, куда её зовут. Меня уже давно зовут.\n(дальше — несколько строк выцвели от времени)"}
  ],
  "note_father_1": [
    {"speaker": "Записка охотника", "text": "Соболь — 3. Белка — 11. Заяц — 4.\nКапкан у второго ручья сломан."}
  ],
  "note_father_2": [
    {"speaker": "Записка охотника", "text": "Ньургун стреляет лучше меня. Парень из бедной семьи, а руки — будто всю жизнь с луком. Дочь смотрит на него.\nНе нравится мне это."}
  ],
  "note_father_3": [
    {"speaker": "Записка охотника", "text": "Видел сегодня след. Не медведь, не сохатый. Кто-то ходит вокруг балагана по ночам. Лайка беспокоится."}
  ],
  "note_father_last": [
    {"speaker": "Записка охотника", "text": "(последняя запись, неровным почерком)\nЗавтра иду с Ньургуном на дальний распадок. Поговорим там. Без свидетелей."}
  ],
  "note_mother_1": [
    {"speaker": "Дневник", "text": "Хомус починила сегодня — Сардаана попросила. Восьмой год ей, а пальцы уже ловкие, как у меня в её возрасте.\nМуж снова ушёл на охоту злым. Не знаю, что с ним стало после той зимы. Раньше смеялся."}
  ],
  "note_mother_2": [
    {"speaker": "Дневник", "text": "Ньургун снова заходил. Принёс рыбы. Я вижу, как он смотрит на дочь — и как она на него. Скоро надо будет говорить с его родителями.\nТолько мужу не говорю пока. Боюсь, заартачится."}
  ],
  "note_mother_3": [
    {"speaker": "Дневник", "text": "Сегодня уронила нож остриём вниз — воткнулся в пол. Бабка моя говорила: к гостю с дурными вестями. Я весь день не отхожу от окна."}
  ],
  "artifact_amulet": [
    {"speaker": "Записка при амулете", "text": "Эту косточку мать бабушки нашла на берегу Лены в год, когда пришла большая вода. Она велела хранить её, бабушка передала матери, мать — мне."},
    {"speaker": "Записка при амулете", "text": "В день, когда я родилась, бабушка вложила её мне в пелёнки и сказала: «Пусть земля помнит тебя живой». Я не понимала этих слов. Теперь понимаю."}
  ],
  "artifact_doll": [
    {"speaker": "Записка при кукле", "text": "Мать сшила её сама — из обрезков шёлка, которые берегла с девичества. Я назвала её Уйбаан. Мать смеялась и говорила, что это мужское имя. Я не соглашалась."},
    {"speaker": "Записка при кукле", "text": "После смерти матери я долго не могла взять куклу в руки — она пахла её духами. Потом запах ушёл. Это было хуже."}
  ],
  "artifact_earring": [
    {"speaker": "Записка при серёжке", "text": "Ньургун нашёл её у старого ювелира в улусе и три месяца откладывал деньги с охоты. Когда протянул мне — смотрел в сторону, уши красные. Я смеялась."},
    {"speaker": "Записка при серёжке", "text": "Потом плакала — уже одна. Серёжка одна — вторую я так и не нашла. Наверное, осталась там, на дальнем распадке. Вместе с ним."}
  ],
  "poem_ritual": [
    {"speaker": "", "text": "На камельке нацарапаны слова:"},
    {"speaker": "", "text": "Три дара легли на алас моей жизни:\nПервый — встретил мой первый вдох,\nВторой — утешал мои детские слёзы,\nТретий — зажёг моё сердце впервые.\nПоложи их в очаг по чреде моих лет —\nИ душа моя выйдет на свет."}
  ],
  "riddle_kamyolk": [
    {"speaker": "Загадка", "text": "«Красная лисица из норы выглядывает, белые щёки лижет — никто не перечит. Спит — погаснет, кормят — растёт.»"}
  ],
  "riddle_bishik": [
    {"speaker": "Загадка", "text": "«Качаюсь — не падаю, пою — не устаю, держу — не отпускаю, расту — да на месте стою.»"}
  ],
  "riddle_mirror": [
    {"speaker": "Загадка", "text": "«В тихой воде живу, никогда не пью. Смотришь — гляжу обратно, отвернёшься — пропаду без следа.»"}
  ]
}
```

- [ ] **Step 2: Create finale.json**

Создать файл `data/dialogues/finale.json`:

```json
{
  "good_part1": [
    {"speaker": "Айыына", "text": "Ты услышал меня. Спустя столько зим — кто-то наконец услышал."},
    {"speaker": "Айыына", "text": "Меня звали Сардаана. Я не успела сказать это никому, кроме матери и Ньургуна. А теперь — и тебе."}
  ],
  "good_part2": [
    {"speaker": "Айыына", "text": "Она ждала со мной. Все эти годы. Теперь — пойдёт со мной туда, где светло."},
    {"speaker": "Айыына", "text": "Уходи из этого дома, пока огонь не догорел. И не возвращайся. Пусть он осыпется и зарастёт травой — так будет правильно."},
    {"speaker": "Айыына", "text": "Спасибо тебе. Иди."}
  ],
  "bad": [
    {"speaker": "", "text": "Огонь погас."},
    {"speaker": "", "text": "Дверь, через которую ты вошёл, больше не открывается. Ты слышишь, как кто-то скребётся в неё снаружи — но это не за тобой."},
    {"speaker": "", "text": "Лайка смотрит на тебя из угла. В её глазах нет узнавания."},
    {"speaker": "", "text": "Теперь вас в этом доме — трое."}
  ]
}
```

- [ ] **Step 3: Commit**

```
git add data/dialogues/notes.json data/dialogues/finale.json
git commit -m "feat: add notes.json and finale.json dialogue data"
```

---

## Task 4: room_entrance — PT-петля и нарастающие тексты двери

**Files:**
- Create: `scripts/rooms/room_entrance_logic.gd`
- Modify: `scenes/rooms/room_entrance.tscn`

- [ ] **Step 1: Create room_entrance_logic.gd**

Создать `scripts/rooms/room_entrance_logic.gd`:

```gdscript
extends Node2D

const LOOP_MESSAGES: Array[String] = [
	"Дверь не поддаётся... Снаружи воет метель.",
	"Дверь не поддаётся. Снаружи — тишина. Метель стихла?",
	"Дверь заперта. На внешней стороне — что-то царапает.",
	"Дверь заперта. За ней — свет. Нужно закончить то, что начато."
]

func _ready() -> void:
	var door := get_node_or_null("DoorOutside")
	if door:
		var idx := clampi(GameManager.loop_state, 0, LOOP_MESSAGES.size() - 1)
		door.lock_message = LOOP_MESSAGES[idx]
	_apply_loop_visuals()

func _apply_loop_visuals() -> void:
	var scratch := get_node_or_null("LoopScratchMarks")
	if scratch:
		scratch.visible = GameManager.loop_state >= 2
```

- [ ] **Step 2: Modify room_entrance.tscn — добавить скрипт и LoopScratchMarks**

Изменить `scenes/rooms/room_entrance.tscn`. Добавить `ext_resource` для нового скрипта, `script` на корневой ноде и `LoopScratchMarks`:

```
[gd_scene load_steps=6 format=3 uid="uid://room_entrance"]

[ext_resource type="Script" path="res://scripts/rooms/room_entrance_logic.gd" id="5"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://door001" path="res://scenes/objects/door.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="PackedScene" uid="uid://examinable001" path="res://scenes/objects/examinable.tscn" id="4"]

[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_floor"]

[node name="RoomEntrance" type="Node2D"]
script = ExtResource("5")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1600.0
offset_bottom = 360.0
color = Color(0.051, 0.031, 0.02, 1)

[node name="FloorVisual" type="ColorRect" parent="."]
offset_top = 320.0
offset_right = 1600.0
offset_bottom = 360.0
color = Color(0.12, 0.08, 0.05, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 320)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("WorldBoundaryShape2D_floor")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(1500, 300)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(1500, 300)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(1600, 180)

[node name="DoorOutside" parent="." instance=ExtResource("2")]
position = Vector2(50, 320)
door_id = "door_outside"
locked = true
lock_message = "Дверь не поддаётся... Снаружи воет метель."

[node name="DoorInside" parent="." instance=ExtResource("2")]
position = Vector2(1550, 320)
door_id = "door_inside"

[node name="Window" parent="." instance=ExtResource("4")]
position = Vector2(800, 320)
examine_text = "В окне — только белое. Метель стала гуще."

[node name="BootsExamine" parent="." instance=ExtResource("4")]
position = Vector2(400, 320)
examine_text = "Чьи-то сапоги у порога. Маленький размер."

[node name="LoopScratchMarks" parent="." instance=ExtResource("4")]
position = Vector2(80, 280)
visible = false
examine_text = "Следы ногтей на двери. Изнутри. Глубокие."

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 3: Verify**

Запустить → из main_hall перейти в entrance → подойти к DoorOutside → текст должен совпадать с LOOP_MESSAGES[0]. После сбора 1 артефакта — перезайти в entrance → текст изменится.

- [ ] **Step 4: Commit**

```
git add scripts/rooms/room_entrance_logic.gd scenes/rooms/room_entrance.tscn
git commit -m "feat: PT loop — dynamic door messages and scratch marks in entrance"
```

---

## Task 5: room_main_hall — загадка камелька + ритуал + PT-изменения

**Files:**
- Modify: `scenes/rooms/room_main_hall.tscn`
- Modify: `scripts/rooms/room_main_hall_logic.gd`

- [ ] **Step 1: Rewrite room_main_hall.tscn**

Полностью заменить содержимое `scenes/rooms/room_main_hall.tscn`:

```
[gd_scene load_steps=10 format=3 uid="uid://room_main_hall"]

[ext_resource type="Script" path="res://scripts/rooms/room_main_hall_logic.gd" id="6"]
[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://door001" path="res://scenes/objects/door.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="PackedScene" uid="uid://laika001" path="res://scenes/characters/laika.tscn" id="4"]
[ext_resource type="PackedScene" uid="uid://examinable001" path="res://scenes/objects/examinable.tscn" id="5"]
[ext_resource type="PackedScene" uid="uid://pickable001" path="res://scenes/objects/pickable.tscn" id="7"]
[ext_resource type="PackedScene" uid="uid://usable001" path="res://scenes/objects/usable.tscn" id="8"]

[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_floor"]

[node name="RoomMainHall" type="Node2D"]
script = ExtResource("6")

[node name="Background" type="ColorRect" parent="."]
offset_right = 2400.0
offset_bottom = 360.0
color = Color(0.102, 0.059, 0.039, 1)

[node name="FloorVisual" type="ColorRect" parent="."]
offset_top = 320.0
offset_right = 2400.0
offset_bottom = 360.0
color = Color(0.176, 0.106, 0.063, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 320)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("WorldBoundaryShape2D_floor")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(1200, 300)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(1200, 300)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(2400, 180)

[node name="DoorEntrance" parent="." instance=ExtResource("2")]
position = Vector2(50, 320)
door_id = "door_entrance"

[node name="DoorLeft" parent="." instance=ExtResource("2")]
position = Vector2(700, 320)
door_id = "door_left"

[node name="DoorRight" parent="." instance=ExtResource("2")]
position = Vector2(2350, 320)
door_id = "door_right"

[node name="Laika" parent="." instance=ExtResource("4")]
position = Vector2(1200, 308)
auto_appear = false

[node name="TableExamine" parent="." instance=ExtResource("5")]
position = Vector2(1600, 320)
examine_text = "Стол накрыт на одного. Тарелка с едой, ещё тёплая. Кто-то ждал гостей."

[node name="WoodPickable" parent="." instance=ExtResource("7")]
position = Vector2(450, 320)
item_id = "firewood"
item_name = "Вязанка дров"
pickup_text = "Берёзовые дрова. Сухие. Кто-то заготовил заранее."

[node name="Kamyolk" parent="." instance=ExtResource("5")]
position = Vector2(2000, 320)
examine_text = ""

[node name="RiddleKamyolk" parent="." instance=ExtResource("5")]
position = Vector2(1800, 280)
examine_text = ""

[node name="KeyPickable" parent="." instance=ExtResource("7")]
position = Vector2(2000, 320)
visible = false
monitoring = false
item_id = "chest_key_1"
item_name = "Ключ от сундука"
pickup_text = "Старый ключ. Нашёлся среди углей камелька."

[node name="ChestAmulet" parent="." instance=ExtResource("8")]
position = Vector2(2200, 320)
required_item = "chest_key_1"
success_text = "Крышка поддаётся. Внутри что-то завёрнуто в старую кожу."
fail_text = "Сундук заперт. Нужен ключ."

[node name="AmuletPickable" parent="." instance=ExtResource("7")]
position = Vector2(2200, 320)
visible = false
monitoring = false
item_id = "amulet"
item_name = "Амулет"
pickup_text = "Древняя косточка. Тёплая на ощупь, будто живая."

[node name="RitualPoem" parent="." instance=ExtResource("5")]
position = Vector2(1400, 280)
examine_text = ""

[node name="NoteAiyyna1" parent="." instance=ExtResource("5")]
position = Vector2(800, 280)
examine_text = ""

[node name="LoopFallenPicture" type="ColorRect" parent="."]
offset_left = 250.0
offset_top = 200.0
offset_right = 290.0
offset_bottom = 260.0
visible = false
color = Color(0.05, 0.03, 0.02, 1)

[node name="LoopWallText" parent="." instance=ExtResource("5")]
position = Vector2(1100, 260)
visible = false
examine_text = "На стене — нацарапано. «УХОДИ». Буквы неровные, будто в спешке."

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 2: Rewrite room_main_hall_logic.gd**

Полностью заменить `scripts/rooms/room_main_hall_logic.gd`:

```gdscript
extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

static var _wake_up_shown: bool = false

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
const CORRECT_ORDER: Array[String] = ["amulet", "doll", "earring"]
const ARTIFACT_NAMES: Dictionary = {
	"amulet": "амулет",
	"doll": "куклу",
	"earring": "серёжку"
}

func _ready() -> void:
	if not _wake_up_shown and ChapterManager.current_chapter == ChapterManager.Chapter.BALAGAN \
			and GameManager.artifacts_collected.is_empty():
		_wake_up_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.start_dialogue("chapter2_balagan/wake_up")

	_apply_loop_visuals()
	_setup_puzzle()

func _setup_puzzle() -> void:
	var amulet_done := GameManager.artifacts_collected.has("amulet")

	if amulet_done:
		for node_name in ["KeyPickable", "ChestAmulet", "AmuletPickable", "WoodPickable"]:
			var n = get_node_or_null(node_name)
			if n:
				n.queue_free()
		kamylok_state = KamylokState.BURNING

	if _all_artifacts_collected():
		kamylok_state = KamylokState.RITUAL_READY

	var kamylok := get_node_or_null("Kamyolk")
	if kamylok:
		kamylok.examined.connect(_on_kamylok_examined)

	var riddle := get_node_or_null("RiddleKamyolk")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_kamyolk"))

	if not amulet_done:
		var chest := get_node_or_null("ChestAmulet")
		if chest:
			chest.item_used.connect(_on_chest_used)
		var amulet := get_node_or_null("AmuletPickable")
		if amulet:
			amulet.picked_up.connect(func(_id): _on_amulet_picked_up())

	var poem := get_node_or_null("RitualPoem")
	if poem:
		poem.examined.connect(func(): DialogueManager.start_dialogue("notes/poem_ritual"))

	var note1 := get_node_or_null("NoteAiyyna1")
	if note1:
		note1.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_1"))

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
			DialogueManager.show_text("", "Пламя вспыхивает ярче. Три дара при тебе.\nВыбери предмет в инвентаре (I), потом подойди к огню снова — в нужном порядке.")
		KamylokState.RITUAL_ACTIVE:
			_place_ritual_artifact()

func _fire_lit() -> void:
	DialogueManager.show_text("", "Ты бросаешь дрова. Огонь занимается медленно, потом ярко — камелёк снова живёт.")
	await DialogueManager.dialogue_finished
	var key := get_node_or_null("KeyPickable")
	if key:
		key.visible = true
		key.set_deferred("monitoring", true)
	DialogueManager.show_text("", "Среди углей что-то поблёскивает. Можно достать.")

func _on_chest_used() -> void:
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	_trigger_flashback("notes/artifact_amulet")

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
		DialogueManager.show_text("", "Пламя вспыхивает белым. Стены перестают дрожать. Что-то освобождается.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("good")
	else:
		DialogueManager.show_text("", "Огонь гаснет. Тишина становится абсолютной.")
		await DialogueManager.dialogue_finished
		GameManager.start_finale("bad")

func _trigger_flashback(dialogue_key: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue(dialogue_key)
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
```

- [ ] **Step 3: Verify**

Запустить → войти в main_hall → найти WoodPickable → подобрать дрова → подойти к Kamyolk → E → огонь зажигается → KeyPickable появляется → подобрать ключ → открыть инвентарь, выбрать ключ → E на сундуке → AmuletPickable появляется → подобрать → флэшбек → артефакт в коллекции.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_main_hall.tscn scripts/rooms/room_main_hall_logic.gd
git commit -m "feat: main_hall — fire puzzle, ritual mechanic, PT loop visuals"
```

---

## Task 6: room_bedroom — загадка колыбели (биhик)

**Files:**
- Modify: `scenes/rooms/room_bedroom.tscn`
- Modify: `scripts/rooms/room_bedroom_logic.gd`

- [ ] **Step 1: Rewrite room_bedroom.tscn**

Полностью заменить `scenes/rooms/room_bedroom.tscn`:

```
[gd_scene load_steps=9 format=3 uid="uid://room_bedroom"]

[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://door001" path="res://scenes/objects/door.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="PackedScene" uid="uid://hideable001" path="res://scenes/objects/hideable.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/rooms/room_bedroom_logic.gd" id="5"]
[ext_resource type="PackedScene" uid="uid://pickable001" path="res://scenes/objects/pickable.tscn" id="6"]
[ext_resource type="PackedScene" uid="uid://examinable001" path="res://scenes/objects/examinable.tscn" id="7"]
[ext_resource type="PackedScene" uid="uid://usable001" path="res://scenes/objects/usable.tscn" id="8"]

[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_floor"]

[node name="RoomBedroom" type="Node2D"]
script = ExtResource("5")

[node name="Background" type="ColorRect" parent="."]
offset_right = 1800.0
offset_bottom = 360.0
color = Color(0.102, 0.051, 0.071, 1)

[node name="FloorVisual" type="ColorRect" parent="."]
offset_top = 320.0
offset_right = 1800.0
offset_bottom = 360.0
color = Color(0.14, 0.08, 0.1, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 320)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("WorldBoundaryShape2D_floor")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(1700, 300)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(1700, 300)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(1800, 180)

[node name="DoorBack" parent="." instance=ExtResource("2")]
position = Vector2(1750, 320)
door_id = "door_back"

[node name="Wardrobe" parent="." instance=ExtResource("4")]
position = Vector2(100, 320)

[node name="BedExamine" parent="." instance=ExtResource("7")]
position = Vector2(800, 320)
examine_text = "Кровать. Постель смята, будто кто-то спал совсем недавно."

[node name="RiddleBishik" parent="." instance=ExtResource("7")]
position = Vector2(550, 280)
examine_text = ""

[node name="Bishik" parent="." instance=ExtResource("7")]
position = Vector2(600, 320)
examine_text = ""

[node name="KeyPickable" parent="." instance=ExtResource("6")]
position = Vector2(600, 320)
visible = false
monitoring = false
item_id = "chest_key_2"
item_name = "Старый ключ"
pickup_text = "Под пелёнкой. Холодный. Кто-то спрятал давно."

[node name="ChestDoll" parent="." instance=ExtResource("8")]
position = Vector2(1400, 320)
required_item = "chest_key_2"
success_text = "Крышка поддаётся. Пахнет старым шёлком."
fail_text = "Сундук заперт."

[node name="DollPickable" parent="." instance=ExtResource("6")]
position = Vector2(1400, 320)
visible = false
monitoring = false
item_id = "doll"
item_name = "Тряпичная кукла"
pickup_text = "Маленькая, в шёлке. Одно ухо надорвано. Тёплая."

[node name="NoteMother1" parent="." instance=ExtResource("7")]
position = Vector2(200, 280)
examine_text = ""

[node name="NoteMother2" parent="." instance=ExtResource("7")]
position = Vector2(380, 280)
examine_text = ""

[node name="NoteMother3" parent="." instance=ExtResource("7")]
position = Vector2(1600, 280)
examine_text = ""

[node name="NoteAiyyna3" parent="." instance=ExtResource("7")]
position = Vector2(1000, 280)
examine_text = ""

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 2: Rewrite room_bedroom_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	if GameManager.artifacts_collected.has("doll"):
		for node_name in ["KeyPickable", "ChestDoll", "DollPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	var riddle := get_node_or_null("RiddleBishik")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_bishik"))

	var bishik := get_node_or_null("Bishik")
	if bishik:
		bishik.examined.connect(_on_bishik_examined)

	var chest := get_node_or_null("ChestDoll")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.picked_up.connect(func(_id): _on_doll_picked_up())

	for note_data in [["NoteMother1", "notes/note_mother_1"], ["NoteMother2", "notes/note_mother_2"],
			["NoteMother3", "notes/note_mother_3"], ["NoteAiyyna3", "notes/note_aiyyna_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_bishik_examined() -> void:
	var key := get_node_or_null("KeyPickable")
	if key and not key.visible:
		DialogueManager.show_text("", "Пустая колыбель. Под покрывалом — что-то твёрдое.")
		await DialogueManager.dialogue_finished
		key.visible = true
		key.set_deferred("monitoring", true)
	else:
		DialogueManager.show_text("", "Колыбель качается сама. Без ребёнка. Без матери.")

func _on_chest_used() -> void:
	var doll := get_node_or_null("DollPickable")
	if doll:
		doll.visible = true
		doll.set_deferred("monitoring", true)

func _on_doll_picked_up() -> void:
	GameManager.collect_artifact("doll")
	_trigger_flashback()

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_doll")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
```

- [ ] **Step 3: Verify**

Войти в bedroom → осмотреть Bishik → ключ появляется → подобрать → выбрать в инвентаре → E на ChestDoll → кукла появляется → подобрать → флэшбек → doll в коллекции.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_bedroom.tscn scripts/rooms/room_bedroom_logic.gd
git commit -m "feat: bedroom — cradle (bishik) puzzle, doll artifact, mother's diary notes"
```

---

## Task 7: room_basement — загадка зеркала

**Files:**
- Modify: `scenes/rooms/room_basement.tscn`
- Modify: `scripts/rooms/room_basement_logic.gd`

- [ ] **Step 1: Rewrite room_basement.tscn**

```
[gd_scene load_steps=8 format=3 uid="uid://room_basement"]

[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://door001" path="res://scenes/objects/door.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="Script" path="res://scripts/rooms/room_basement_logic.gd" id="4"]
[ext_resource type="PackedScene" uid="uid://pickable001" path="res://scenes/objects/pickable.tscn" id="5"]
[ext_resource type="PackedScene" uid="uid://spirit_guardian" path="res://scenes/characters/spirit_guardian.tscn" id="6"]
[ext_resource type="PackedScene" uid="uid://examinable001" path="res://scenes/objects/examinable.tscn" id="7"]
[ext_resource type="PackedScene" uid="uid://usable001" path="res://scenes/objects/usable.tscn" id="8"]

[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_floor"]

[node name="RoomBasement" type="Node2D"]
script = ExtResource("4")

[node name="Background" type="ColorRect" parent="."]
offset_right = 2200.0
offset_bottom = 360.0
color = Color(0.02, 0.008, 0.012, 1)

[node name="FloorVisual" type="ColorRect" parent="."]
offset_top = 320.0
offset_right = 2200.0
offset_bottom = 360.0
color = Color(0.05, 0.03, 0.035, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 320)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("WorldBoundaryShape2D_floor")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(100, 300)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(100, 300)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(2200, 180)

[node name="DoorUp" parent="." instance=ExtResource("2")]
position = Vector2(50, 320)
door_id = "door_up"

[node name="NoteAiyyna5" parent="." instance=ExtResource("7")]
position = Vector2(400, 280)
examine_text = ""

[node name="RiddleMirror" parent="." instance=ExtResource("7")]
position = Vector2(850, 280)
examine_text = ""

[node name="OldMirror" parent="." instance=ExtResource("7")]
position = Vector2(900, 320)
examine_text = ""

[node name="KeyPickable" parent="." instance=ExtResource("5")]
position = Vector2(1100, 320)
visible = false
monitoring = false
item_id = "chest_key_3"
item_name = "Ключ"
pickup_text = "За зеркалом. Холодный. Как будто ждал."

[node name="ChestEarring" parent="." instance=ExtResource("8")]
position = Vector2(1700, 320)
required_item = "chest_key_3"
success_text = "Сундук открыт. Внутри — что-то серебристое."
fail_text = "Сундук заперт."

[node name="EarringPickable" parent="." instance=ExtResource("5")]
position = Vector2(1700, 320)
visible = false
monitoring = false
item_id = "earring"
item_name = "Серёжка"
pickup_text = "Серебряная. Одна. На внутренней стороне — имя: «Сардаана»."

[node name="SpiritGuardian" parent="." instance=ExtResource("6")]
position = Vector2(1500, 320)

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 2: Rewrite room_basement_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	if GameManager.artifacts_collected.has("earring"):
		for node_name in ["KeyPickable", "ChestEarring", "EarringPickable"]:
			var n := get_node_or_null(node_name)
			if n:
				n.queue_free()
		return

	var riddle := get_node_or_null("RiddleMirror")
	if riddle:
		riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_mirror"))

	var mirror := get_node_or_null("OldMirror")
	if mirror:
		mirror.examined.connect(_on_mirror_examined)

	var chest := get_node_or_null("ChestEarring")
	if chest:
		chest.item_used.connect(_on_chest_used)

	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.picked_up.connect(func(_id): _on_earring_picked_up())

	var note5 := get_node_or_null("NoteAiyyna5")
	if note5:
		note5.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_5"))

func _on_mirror_examined() -> void:
	var key := get_node_or_null("KeyPickable")
	if key and not key.visible:
		DialogueManager.show_text("", "Старое зеркало. В отражении — тот же подвал, но немного другой. За зеркалом что-то блестит.")
		await DialogueManager.dialogue_finished
		key.visible = true
		key.set_deferred("monitoring", true)
	else:
		DialogueManager.show_text("", "В отражении видишь себя. Позади — тень, которой нет.")

func _on_chest_used() -> void:
	var earring := get_node_or_null("EarringPickable")
	if earring:
		earring.visible = true
		earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
	GameManager.collect_artifact("earring")
	_trigger_flashback()

func _trigger_flashback() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()
	var bg := $Background as ColorRect
	var original_color := bg.color
	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.24, 0.17, 0.1), 1.0)
	await tween.finished
	await get_tree().create_timer(2.0).timeout
	DialogueManager.start_dialogue("notes/artifact_earring")
	await DialogueManager.dialogue_finished
	tween = create_tween()
	tween.tween_property(bg, "color", original_color, 1.0)
	await tween.finished
	if fl:
		fl.scripted_on()
```

- [ ] **Step 3: Verify**

Войти в basement → осмотреть зеркало → ключ появляется → подобрать → выбрать → сундук → серёжка → флэшбек → earring в коллекции.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_basement.tscn scripts/rooms/room_basement_logic.gd
git commit -m "feat: basement — mirror puzzle, earring artifact"
```

---

## Task 8: room_storage — упростить до лор-комнаты

**Files:**
- Modify: `scenes/rooms/room_storage.tscn`
- Modify: `scripts/rooms/room_storage_logic.gd`

- [ ] **Step 1: Rewrite room_storage.tscn**

```
[gd_scene load_steps=7 format=3 uid="uid://room_storage"]

[ext_resource type="PackedScene" uid="uid://player001" path="res://scenes/player/player.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://door001" path="res://scenes/objects/door.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://hud001" path="res://scenes/ui/hud.tscn" id="3"]
[ext_resource type="PackedScene" uid="uid://hideable001" path="res://scenes/objects/hideable.tscn" id="4"]
[ext_resource type="Script" path="res://scripts/rooms/room_storage_logic.gd" id="5"]
[ext_resource type="PackedScene" uid="uid://examinable001" path="res://scenes/objects/examinable.tscn" id="6"]

[sub_resource type="WorldBoundaryShape2D" id="WorldBoundaryShape2D_floor"]

[node name="RoomStorage" type="Node2D"]
script = ExtResource("5")

[node name="Background" type="ColorRect" parent="."]
offset_right = 2000.0
offset_bottom = 360.0
color = Color(0.071, 0.051, 0.031, 1)

[node name="FloorVisual" type="ColorRect" parent="."]
offset_top = 320.0
offset_right = 2000.0
offset_bottom = 360.0
color = Color(0.11, 0.08, 0.05, 1)

[node name="Floor" type="StaticBody2D" parent="."]
position = Vector2(0, 320)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Floor"]
shape = SubResource("WorldBoundaryShape2D_floor")

[node name="Player" parent="." instance=ExtResource("1")]
position = Vector2(1900, 300)

[node name="SpawnPoint" type="Marker2D" parent="."]
position = Vector2(1900, 300)

[node name="RoomRight" type="Marker2D" parent="."]
position = Vector2(2000, 180)

[node name="DoorBack" parent="." instance=ExtResource("2")]
position = Vector2(1950, 320)
door_id = "door_back"

[node name="HideableBox" parent="." instance=ExtResource("4")]
position = Vector2(150, 320)

[node name="StorageShelf" parent="." instance=ExtResource("6")]
position = Vector2(600, 320)
examine_text = "Полки с припасами. Всё в порядке — кто-то хозяйничал здесь недавно."

[node name="OldTrap" parent="." instance=ExtResource("6")]
position = Vector2(1200, 320)
examine_text = "Охотничий капкан. Ржавый. Давно не использовался."

[node name="NoteAiyyna4" parent="." instance=ExtResource("6")]
position = Vector2(900, 280)
examine_text = ""

[node name="HUD" parent="." instance=ExtResource("3")]
```

- [ ] **Step 2: Rewrite room_storage_logic.gd**

```gdscript
extends Node2D

func _ready() -> void:
	var note4 := get_node_or_null("NoteAiyyna4")
	if note4:
		note4.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_4"))
```

- [ ] **Step 3: Verify**

Войти в storage → осмотреть NoteAiyyna4 → текст записки о быке показывается через DialogueManager.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_storage.tscn scripts/rooms/room_storage_logic.gd
git commit -m "feat: storage — lore room with Ayiyna note 4 (bull), remove stone puzzle"
```

---

## Task 9: room_highway — записки отца

**Files:**
- Modify: `scenes/rooms/room_highway.tscn`
- Modify: `scripts/rooms/room_highway_logic.gd`

- [ ] **Step 1: Read current room_highway.tscn and add note nodes**

Открыть `scenes/rooms/room_highway.tscn`. Добавить три ноды `NoteFather1/2/3` и `ExamineSnow` перед `[node name="HUD"...]`. Также добавить `ext_resource` для examinable если его нет.

Добавить в конец файла (перед строкой с HUD):

```
[node name="NoteFather1" parent="." instance=ExtResource("examinable_id")]
position = Vector2(350, 320)
examine_text = ""

[node name="NoteFather2" parent="." instance=ExtResource("examinable_id")]
position = Vector2(900, 320)
examine_text = ""

[node name="NoteFather3" parent="." instance=ExtResource("examinable_id")]
position = Vector2(1450, 320)
examine_text = ""
```

> **Примечание:** `examinable_id` — это id из ext_resource блока в начале файла. Прочитай файл и используй существующий id для examinable или добавь новый ext_resource.

- [ ] **Step 2: Update room_highway_logic.gd**

```gdscript
extends Node2D

var _intro_shown: bool = false

func _ready() -> void:
	var zone := get_node_or_null("TriggerZone")
	if zone:
		zone.body_entered.connect(_on_zone_entered)
	if not _intro_shown:
		_intro_shown = true
		await get_tree().process_frame
		await get_tree().process_frame
		DialogueManager.start_dialogue("highway_arrival")

	for note_data in [["NoteFather1", "notes/note_father_1"], ["NoteFather2", "notes/note_father_2"],
			["NoteFather3", "notes/note_father_3"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_zone_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.change_room("door_continue")
```

- [ ] **Step 3: Verify**

Старт новой игры → highway → осмотреть NoteFather1/2/3 → тексты записок охотника показываются.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_highway.tscn scripts/rooms/room_highway_logic.gd
git commit -m "feat: highway — father hunting notes (3 entries)"
```

---

## Task 10: room_forest — место убийства и записки

**Files:**
- Modify: `scenes/rooms/room_forest.tscn`
- Modify: `scripts/rooms/room_forest_logic.gd`

- [ ] **Step 1: Add nodes to room_forest.tscn**

В `scenes/rooms/room_forest.tscn` добавить три ноды перед `[node name="HUD"...]`:

```
[node name="MurderSite" parent="." instance=ExtResource("4")]
position = Vector2(1800, 320)
examine_text = ""

[node name="NoteFatherLast" parent="." instance=ExtResource("4")]
position = Vector2(1500, 280)
examine_text = ""

[node name="NoteAiyyna2" parent="." instance=ExtResource("4")]
position = Vector2(1000, 280)
examine_text = ""
```

> `ExtResource("4")` — это examinable (уже используется в сцене для BrokenBranch и других).

- [ ] **Step 2: Update room_forest_logic.gd**

```gdscript
extends Node2D

var _laika_appeared: bool = false
var _chapter_started: bool = false

func _ready() -> void:
	var laika_trigger := get_node_or_null("LaikaTrigger")
	if laika_trigger:
		laika_trigger.body_entered.connect(_on_laika_trigger)
	var exit_zone := get_node_or_null("ExitZone")
	if exit_zone:
		exit_zone.body_entered.connect(_on_exit_zone)

	var murder := get_node_or_null("MurderSite")
	if murder:
		murder.examined.connect(_on_murder_site_examined)

	for note_data in [["NoteFatherLast", "notes/note_father_last"],
			["NoteAiyyna2", "notes/note_aiyyna_2"]]:
		var note := get_node_or_null(note_data[0])
		var key: String = note_data[1]
		if note:
			note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_murder_site_examined() -> void:
	DialogueManager.show_text("", "Примятая трава. Старые следы борьбы. Снег здесь давно покраснел и стал чёрным.")
	await DialogueManager.dialogue_finished
	DialogueManager.show_text("", "Это место знакомо. Будто кто-то оставил здесь часть себя — навсегда.")

func _on_laika_trigger(body: Node2D) -> void:
	if not body.is_in_group("player") or _laika_appeared:
		return
	_laika_appeared = true

	if body.has_method("freeze"):
		body.freeze()

	var laika := get_node_or_null("Laika")
	if laika:
		laika.appear()

	DialogueManager.show_text("", "Лайка... Она здесь? Откуда?")
	await DialogueManager.dialogue_finished

	if laika and is_instance_valid(laika):
		laika.set_physics_process(false)
		var anim: AnimatedSprite2D = laika.get_node_or_null("AnimatedSprite2D")
		if anim:
			anim.flip_h = false
			anim.play("walk")
		var tween := create_tween()
		tween.tween_property(laika, "global_position:x", laika.global_position.x + 520.0, 1.6)
		tween.parallel().tween_property(laika, "modulate:a", 0.0, 1.6)
		await tween.finished
		laika.visible = false

	if body.has_method("unfreeze"):
		body.unfreeze()

func _on_exit_zone(body: Node2D) -> void:
	if body.is_in_group("player") and not _chapter_started:
		_chapter_started = true
		ChapterManager.start_chapter(ChapterManager.Chapter.BALAGAN)
```

- [ ] **Step 3: Verify**

Запустить → пройти лес → осмотреть MurderSite → текст о борьбе. Осмотреть NoteAiyyna2 → записка об охоте. Осмотреть NoteFatherLast → последняя запись.

- [ ] **Step 4: Commit**

```
git add scenes/rooms/room_forest.tscn scripts/rooms/room_forest_logic.gd
git commit -m "feat: forest — murder site, Ayiyna note 2, father's last note"
```

---

## Task 11: finale.gd — хорошая и плохая концовки

**Files:**
- Modify: `scripts/rooms/finale.gd`

- [ ] **Step 1: Rewrite finale.gd**

```gdscript
extends Node2D

func _ready() -> void:
	ChapterManager.current_chapter = ChapterManager.Chapter.RELEASE
	await get_tree().process_frame
	if GameManager.ritual_result == "good":
		_start_good_ending()
	else:
		_start_bad_ending()

func _start_good_ending() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	var laika := get_tree().get_first_node_in_group("laika")
	var bg := $Background as ColorRect

	if fl:
		fl.scripted_off()

	await get_tree().create_timer(1.0).timeout

	var tween := create_tween()
	tween.tween_property(bg, "color", Color(0.165, 0.102, 0.039), 2.0)
	await tween.finished

	DialogueManager.start_dialogue("finale/good_part1")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout

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
		DialogueManager.show_text("", "Тихий скулёж. Она светится — так же, как Айыына.")
		await DialogueManager.dialogue_finished
		await laika_tween.finished

	await get_tree().create_timer(2.0).timeout
	_post_credits(bg)

func _start_bad_ending() -> void:
	var bg := $Background as ColorRect
	var player := get_tree().get_first_node_in_group("player")
	var fl = player.get_node("Flashlight") if player else null
	if fl:
		fl.scripted_off()

	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	DialogueManager.start_dialogue("finale/bad")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")

func _post_credits(bg: ColorRect) -> void:
	var tween := create_tween()
	tween.tween_property(bg, "color", Color.BLACK, 2.0)
	await tween.finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "Машина заводится. Связь появилась.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(1.0).timeout
	DialogueManager.show_text("", "На заднем сиденье — амулет. И рядом... маленький клок шерсти.")
	await DialogueManager.dialogue_finished

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/credits.tscn")
```

- [ ] **Step 2: Verify хорошую концовку**

Запустить → собрать все 3 артефакта → провести ритуал в правильном порядке (amulet→doll→earring) → `ritual_result = "good"` → появляется финальный диалог Сарданы → лайка растворяется → credits.

- [ ] **Step 3: Verify плохую концовку**

Запустить → собрать все 3 артефакта → положить в неправильном порядке → `ritual_result = "bad"` → чёрный экран → текст плохой концовки → credits.

- [ ] **Step 4: Commit**

```
git add scripts/rooms/finale.gd
git commit -m "feat: finale — good/bad endings based on ritual_result"
```

---

## Task 12: Расширение высоты всех комнат (360 → 700px)

**Files:**
- Modify: все `scenes/rooms/*.tscn`
- Already done in Task 2: `scripts/autoload/game_manager.gd` — dynamic camera.limit_bottom

**Принцип:** В каждой сцене:
- `Background.offset_bottom`: 360 → 700
- `FloorVisual.offset_top`: 320 → 660, `offset_bottom`: 360 → 700
- `Floor StaticBody2D position.y`: 320 → 660
- `SpawnPoint position.y`: старое → 640
- `Player position.y`: старое → 640
- Все двери `position.y`: 320 → 660
- Все объекты взаимодействия `position.y`: 320 → 660
- Добавить `RoomBottom Marker2D` с `position = Vector2(0, 700)`

> `game_manager.gd` уже обновлён в Task 2 для чтения `RoomBottom`. Камера будет корректно ограничена снизу.

- [ ] **Step 1: Extend room_main_hall.tscn (2400×700)**

В `room_main_hall.tscn` изменить:
```
# Background
offset_bottom = 700.0

# FloorVisual
offset_top = 660.0
offset_bottom = 700.0

# Floor
position = Vector2(0, 660)

# SpawnPoint
position = Vector2(1200, 640)

# Player
position = Vector2(1200, 640)

# DoorEntrance
position = Vector2(50, 660)

# DoorLeft
position = Vector2(700, 660)

# DoorRight
position = Vector2(2350, 660)

# TableExamine
position = Vector2(1600, 660)

# WoodPickable
position = Vector2(450, 660)

# Kamyolk
position = Vector2(2000, 660)

# RiddleKamyolk
position = Vector2(1800, 620)

# KeyPickable
position = Vector2(2000, 660)

# ChestAmulet
position = Vector2(2200, 660)

# AmuletPickable
position = Vector2(2200, 660)

# RitualPoem
position = Vector2(1400, 620)

# NoteAiyyna1
position = Vector2(800, 620)

# LoopFallenPicture
offset_top = 540.0
offset_bottom = 600.0

# LoopWallText
position = Vector2(1100, 600)

# Добавить перед [node name="HUD"...]:
[node name="RoomBottom" type="Marker2D" parent="."]
position = Vector2(0, 700)
```

- [ ] **Step 2: Extend room_bedroom.tscn (1800×700)**

Аналогично: Background offset_bottom=700, FloorVisual y 660→700, Floor y=660, SpawnPoint/Player y=640, все объекты y=660, добавить RoomBottom.

- [ ] **Step 3: Extend room_basement.tscn (2200×700)**

Аналогично всем паттернам выше.

- [ ] **Step 4: Extend room_storage.tscn (2000×700)**

Аналогично.

- [ ] **Step 5: Extend room_corridor.tscn (1280×700)**

Прочитать файл, применить паттерн.

- [ ] **Step 6: Extend room_entrance.tscn (1600×700)**

Аналогично.

- [ ] **Step 7: Extend room_highway.tscn и room_forest.tscn**

room_highway: аналогично. room_forest: дополнительно обновить все деревья (Trunk*/Canopy*) — их `offset_bottom` остаётся без изменений (они не касаются пола), но `BalaganSilhouette`, `BalaganRoof`, `FloorVisual`, `SnowGround`, `PathLight`, `Floor` — обновить по паттерну.

- [ ] **Step 8: Verify**

Запустить → зайти в несколько комнат → убедиться что пол виден, игрок стоит на нём, камера правильно ограничена снизу (не показывает пустоту ниже пола).

- [ ] **Step 9: Commit**

```
git add scenes/rooms/
git commit -m "feat: extend all rooms height 360px→700px, dynamic camera limit_bottom"
```

---

## Checklist: финальная проверка

- [ ] Двери работают (E при подходе к двери → переход)
- [ ] Загадка 1 (камелёк): дрова → огонь → ключ → сундук → амулет → флэшбек
- [ ] Загадка 2 (биhик): колыбель → ключ → сундук → кукла → флэшбек
- [ ] Загадка 3 (зеркало): зеркало → ключ → сундук → серёжка → флэшбек
- [ ] После 3 артефактов: камелёк показывает ritual_ready
- [ ] Ритуал правильный (amulet→doll→earring): хорошая концовка
- [ ] Ритуал неправильный: плохая концовка
- [ ] PT-петля: дверь снаружи заперта, сообщения меняются с loop_state
- [ ] loop_state 1: fallen picture видна в main_hall
- [ ] loop_state 2: wall_text и scratch_marks видны
- [ ] Записки (5 флэшбеков, 3 матери, 4 отца) читаются в нужных комнатах
- [ ] Все комнаты 700px, камера правильно ограничена
