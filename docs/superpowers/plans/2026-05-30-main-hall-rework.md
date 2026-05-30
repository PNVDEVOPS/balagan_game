# Main Hall Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Переработать room_main_hall — убрать wake_up монолог, заменить пазл ключ→сундук на задвижку камелька с харысхалом, добавить появление Кыдааны после розжига, заблокировать выход до получения артефакта.

**Architecture:** Записка о харысхале переносится в коридор entry_c4 (тумба) как pre-puzzle подсказка. В зале добавляется нода Damper (задвижка) и FoxRiddleCarving (вырезка на стене). Камелёк-флоу: взять дрова → попробовать разжечь → диалог о задвижке → открыть задвижку → харысхал падает → взять → разжечь → Кыдаана. Флэшбек после подбора убирается — записка уже прочитана ранее.

**Tech Stack:** Godot 4.6, GDScript, DialogueManager, SubtitleManager, Inventory, GameManager

---

## File Map

| Файл | Действие |
|---|---|
| `data/dialogues/notes.json` | Добавить `note_haryshal` |
| `scripts/rooms/room_corridor_logic.gd` | entry_c4 → note_haryshal |
| `scenes/rooms/room_main_hall.tscn` | Убрать ChestAmulet/KeyPickable, добавить Damper + FoxRiddleCarving, переставить AmuletPickable |
| `scripts/rooms/room_main_hall_logic.gd` | Полная переработка пазл-логики |

---

## Task 1: Добавить note_haryshal в notes.json

**Files:**
- Modify: `data/dialogues/notes.json`

- [ ] **Step 1: Добавить ключ note_haryshal**

Открой `data/dialogues/notes.json`. Добавь после `"riddle_mirror"` блока:

```json
  "note_haryshal": [
    {"speaker": "Записка", "text": "Эту косточку мать бабушки нашла на берегу Лены в год большой воды. Говорила: береги её — и она убережёт тебя."},
    {"speaker": "Записка", "text": "Когда я родилась, бабушка вложила её мне в пелёнки. Что-то пела тихо — я запомнила только слова:"},
    {"speaker": "Записка", "text": "Красная лисица из норы выглядывает,\nбелые щёки лижет — никто не перечит.\nСпит — погаснет, кормят — растёт."}
  ],
```

Это pre-puzzle записка: история о харысхале + загадка про огонь в конце. Нет фразы «положи туда, где живёт лисица» — игрок сам должен соединить.

- [ ] **Step 2: Commit**

```powershell
git add data/dialogues/notes.json
git commit -m "content: add note_haryshal — pre-puzzle amulet note for corridor"
```

---

## Task 2: Подключить note_haryshal в entry_c4

**Files:**
- Modify: `scripts/rooms/room_corridor_logic.gd`

- [ ] **Step 1: Добавить entry_c4 в _setup_note и задать interaction_text**

Найди функцию `_setup_note`. Замени:

```gdscript
func _setup_note(note: Node, room_id: String) -> void:
	var note_key := ""
	match room_id:
		"entry_c1": note_key = "note_env_2"
		"corridor2": note_key = "note_father_4"
	if note_key.is_empty():
		note.queue_free()
		return
	note.examined.connect(func():
		DialogueManager.start_dialogue("notes/" + note_key)
		GameManager.mark_note_found(note_key)
	)
```

На:

```gdscript
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
```

- [ ] **Step 2: Commit**

```powershell
git add scripts/rooms/room_corridor_logic.gd
git commit -m "feat: entry_c4 corridor shows haryshal note on tumba"
```

---

## Task 3: Обновить room_main_hall.tscn

**Files:**
- Modify: `scenes/rooms/room_main_hall.tscn`

- [ ] **Step 1: Убрать ChestAmulet и KeyPickable, добавить Damper и FoxRiddleCarving**

Найди и удали эти два блока из сцены:

```
[node name="KeyPickable" ...]
[node name="ChestAmulet" ...]
```

Найди `AmuletPickable` и измени его позицию на x=1900 (рядом с задвижкой):

```
[node name="AmuletPickable" parent="." unique_id=1043989766 instance=ExtResource("7")]
visible = false
position = Vector2(1900, 660)
monitoring = false
item_id = "amulet"
item_name = "Харысхал"
pickup_text = "Харысхал. Тёплый на ощупь — будто жил в тепле все эти годы."
```

Добавь два новых узла перед `[node name="LoopFallenPicture"`:

```
[node name="Damper" parent="." unique_id=242742009 instance=ExtResource("5")]
position = Vector2(1900, 620)
examine_text = "Чугунная задвижка дымохода."
interaction_text = "Осмотреть задвижку"

[node name="FoxRiddleCarving" parent="." unique_id=242742010 instance=ExtResource("5")]
position = Vector2(500, 580)
examine_text = "Красная лисица из норы выглядывает,\nбелые щёки лижет — никто не перечит.\nСпит — погаснет, кормят — растёт."
interaction_text = "Прочитать надпись"
```

ExtResource("5") — это `examinable.tscn` (uid://2uqwlc1065aa), уже используется в сцене.

- [ ] **Step 2: Commit**

```powershell
git add scenes/rooms/room_main_hall.tscn
git commit -m "feat: main_hall — add Damper + FoxRiddleCarving, remove chest/key, reposition amulet"
```

---

## Task 4: Переписать room_main_hall_logic.gd

**Files:**
- Modify: `scripts/rooms/room_main_hall_logic.gd`

- [ ] **Step 1: Заменить весь файл**

```gdscript
extends Node2D

enum KamylokState { COLD, BURNING, RITUAL_READY, RITUAL_ACTIVE }

var kamylok_state: KamylokState = KamylokState.COLD
var ritual_items: Array[String] = []
var _idle_subtitle_timer: float = 0.0
var _idle_subtitle_shown: bool = false
var _damper_open: bool = false
const CORRECT_ORDER: Array[String] = ["amulet", "doll", "earring"]
const ARTIFACT_NAMES: Dictionary = {
	"amulet": "харысхал",
	"doll": "куклу",
	"earring": "серёжку"
}

func _ready() -> void:
	_apply_loop_visuals()
	_setup_puzzle()

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

	if amulet_done:
		for node_name in ["Damper", "AmuletPickable", "WoodPickable"]:
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

	var fox_carving := get_node_or_null("FoxRiddleCarving")
	if fox_carving:
		fox_carving.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_kamyolk"))

	var damper := get_node_or_null("Damper")
	if damper and not amulet_done:
		damper.examined.connect(_on_damper_examined)

	if not amulet_done:
		var amulet := get_node_or_null("AmuletPickable")
		if amulet:
			amulet.picked_up.connect(func(_id): _on_amulet_picked_up())

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
	match kamylok_state:
		KamylokState.COLD:
			DialogueManager.show_text("", "Камелёк — глиняный очаг, обложенный жердями. Угли холодные. Давно не топили.")
		KamylokState.BURNING:
			DialogueManager.show_text("", "Огонь горит ровно. Тепло наконец.")
		KamylokState.RITUAL_READY:
			DialogueManager.show_text("", "Пламя стало другим — тихое, почти прозрачное. Ждёт даров.")
	await DialogueManager.dialogue_finished
	match kamylok_state:
		KamylokState.COLD:
			if Inventory.has_item("firewood"):
				if not _damper_open:
					DialogueManager.show_text("", "Задвижка дымохода закрыта. Если разжечь так — дымом задохнусь. Надо сначала открыть её.")
				else:
					Inventory.remove_item("firewood")
					kamylok_state = KamylokState.BURNING
					_fire_lit()
			else:
				DialogueManager.show_text("", "Угли холодные. Нужно дров.")
		KamylokState.RITUAL_READY:
			kamylok_state = KamylokState.RITUAL_ACTIVE
			DialogueManager.show_text("", "Пламя ждёт.")

func _on_damper_examined() -> void:
	if _damper_open:
		DialogueManager.show_text("", "Задвижка открыта.")
		return
	DialogueManager.show_text("", "Чугунная задвижка дымохода. Закрыта.")
	await DialogueManager.dialogue_finished
	_damper_open = true
	DialogueManager.show_text("", "Открываю. Что-то падает на поленья — маленькое, тёмное.")
	await DialogueManager.dialogue_finished
	var amulet := get_node_or_null("AmuletPickable")
	if amulet:
		amulet.visible = true
		amulet.set_deferred("monitoring", true)

func _fire_lit() -> void:
	DialogueManager.show_text("", "Ты бросаешь дрова. Огонь занимается медленно, потом ярко — камелёк снова живёт.")
	await DialogueManager.dialogue_finished
	await get_tree().create_timer(1.0).timeout
	_show_kydaana_spirit()

func _on_amulet_picked_up() -> void:
	GameManager.collect_artifact("amulet")
	DialogueManager.show_text("", "Харысхал. Косточка, тёплая на ощупь — будто жила в тепле все эти годы.")

func _show_kydaana_spirit() -> void:
	var silhouette := Sprite2D.new()
	var tex_path := "res://assets/sprites/ghost_figure.webp"
	if ResourceLoader.exists(tex_path):
		silhouette.texture = load(tex_path)
	silhouette.modulate = Color(0.2, 0.2, 0.5, 0.0)
	silhouette.position = Vector2(1400, 580)
	silhouette.scale = Vector2(1.8, 1.8)
	add_child(silhouette)

	var tw := create_tween()
	tw.tween_property(silhouette, "modulate:a", 0.75, 2.5)
	tw.tween_interval(5.0)
	# TBD: Кыдаана реплики и реакция героя добавить здесь
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

func _process(delta: float) -> void:
	if _idle_subtitle_shown:
		return
	_idle_subtitle_timer += delta
	if _idle_subtitle_timer >= 10.0:
		_idle_subtitle_shown = true
		SubtitleManager.show_subtitle("Холодно.", SubtitleManager.Pos.MID_RIGHT)
```

- [ ] **Step 2: Commit**

```powershell
git add scripts/rooms/room_main_hall_logic.gd
git commit -m "feat: rework main_hall — damper puzzle, haryshal, Kydaana spirit, exit gate"
```

---

## Task 5: Проверка в игре

- [ ] **Step 1: Запустить игру, пройти entry_c4**

Дойди до entry_c4. Убедись что на тумбе есть `[E] Осмотреть записку на тумбе`. Прочитай — должны появиться 3 строки о харысхале + загадка про лисицу без подсказки куда класть.

- [ ] **Step 2: Войти в зал**

Убедись что:
- Wake_up монолог не появляется
- Найда у камелька (если есть в сцене)
- Вырезка на стене `[E] Прочитать надпись` — та же загадка про лисицу

- [ ] **Step 3: Пазл камелька**

1. Подойти к камельку `[E]` → «Угли холодные. Нужно дров.»
2. Взять дрова → снова `[E]` на камелёк → «Задвижка закрыта...»
3. `[E]` на задвижку → «Открываю. Что-то падает на поленья.»
4. Появляется харысхал на полу → подобрать → «Харысхал. Тёплый на ощупь...»
5. `[E]` на камелёк → разжигается → Кыдаана появляется как призрак, медленно проявляется и исчезает

- [ ] **Step 4: Проверить блокировку выхода**

Попробовать дойти до ExitZone до получения харысхала → субтитр «Что-то не отпускает меня.», переход не происходит. После получения — выход работает.

- [ ] **Step 5: Commit**

```powershell
git add .
git commit -m "fix: main_hall rework verified and working"
```

---

## TBD (вне этого плана)

- Реплики Кыдааны при первом появлении и реакция героя — добавить в `_show_kydaana_spirit()` после `tw.tween_interval(5.0)`
- Визуальный арт задвижки (сейчас placeholder-нода без спрайта)
- Найда у камелька — пока только если нода Laika уже есть в сцене в нужной позиции
