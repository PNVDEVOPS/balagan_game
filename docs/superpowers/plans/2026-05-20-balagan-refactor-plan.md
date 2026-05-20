# Балаган — Aggressive Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Агрессивный рефакторинг «Балагана» — исправить имена/тексты, убрать лишние комнаты, добавить мини-игры «Пятнашки» и «Осколки зеркала», переписать механику духов на hold-F вместо QTE.

**Architecture:** Четыре фазы: (1) контент и данные, (2) UI подсветки взаимодействий, (3) новые мини-игры как CanvasLayer-оверлеи, (4) переписанный дух + flashlight boost. Каждая фаза коммитится отдельно. Лишние комнаты (corridor, entrance, storage) → `_legacy/`.

**Tech Stack:** Godot 4.3+, GDScript typed (`var x: int := 0`), JSON для диалогов/записок, 2D CharacterBody2D.

---

## File Map

| Действие | Файл |
|---|---|
| Move to _legacy | `scenes/rooms/room_corridor.tscn`, `scenes/rooms/room_entrance.tscn`, `scenes/rooms/room_storage.tscn` |
| Move to _legacy | `scripts/rooms/room_corridor_logic.gd`, `scripts/rooms/room_entrance_logic.gd`, `scripts/rooms/room_storage_logic.gd` |
| Rewrite | `data/room_graph.json` |
| Rewrite | `data/dialogues/notes.json` |
| Rewrite | `data/dialogues/chapter2_balagan.json` |
| Modify | `scripts/rooms/room_main_hall_logic.gd` |
| Rewrite | `scripts/rooms/room_bedroom_logic.gd` |
| Rewrite | `scripts/rooms/room_basement_logic.gd` |
| Rewrite | `scripts/rooms/room_highway_logic.gd` |
| Modify | `scripts/rooms/room_forest_logic.gd` |
| Modify | `scripts/player/player.gd` |
| Modify | `scripts/player/flashlight.gd` |
| Create | `scripts/minigames/minigame_cradle.gd` |
| Create | `scenes/minigames/minigame_cradle.tscn` |
| Create | `scripts/minigames/minigame_mirror.gd` |
| Create | `scenes/minigames/minigame_mirror.tscn` |
| Rewrite | `scripts/characters/spirit_guardian.gd` |
| Modify | `scripts/ui/main_menu.gd` |

---

## PHASE 1 — Content & Names

---

### Task 1: Archive legacy rooms + fix room_graph.json

**Files:**
- Move to `_legacy/`: `scenes/rooms/room_corridor.tscn`, `scenes/rooms/room_entrance.tscn`, `scenes/rooms/room_storage.tscn`
- Move to `_legacy/`: `scripts/rooms/room_corridor_logic.gd`, `scripts/rooms/room_entrance_logic.gd`, `scripts/rooms/room_storage_logic.gd`
- Move to `_legacy/`: `data/dialogues/highway_arrival.json`
- Rewrite: `data/room_graph.json`

- [ ] **Step 1: Create `_legacy/` directory and move files**

```powershell
mkdir -Force "_legacy/scenes/rooms"
mkdir -Force "_legacy/scripts/rooms"
mkdir -Force "_legacy/data/dialogues"
Move-Item "scenes/rooms/room_corridor.tscn" "_legacy/scenes/rooms/"
Move-Item "scenes/rooms/room_entrance.tscn" "_legacy/scenes/rooms/"
Move-Item "scenes/rooms/room_storage.tscn" "_legacy/scenes/rooms/"
Move-Item "scripts/rooms/room_corridor_logic.gd" "_legacy/scripts/rooms/"
Move-Item "scripts/rooms/room_entrance_logic.gd" "_legacy/scripts/rooms/"
Move-Item "scripts/rooms/room_storage_logic.gd" "_legacy/scripts/rooms/"
Move-Item "data/dialogues/highway_arrival.json" "_legacy/data/dialogues/"
```

- [ ] **Step 2: Rewrite `data/room_graph.json`**

Replace the entire file with:

```json
{
  "rooms": {
    "main_hall": {
      "scene": "res://scenes/rooms/room_main_hall.tscn",
      "doors": {
        "door_bedroom": "bedroom",
        "door_basement": "basement"
      }
    },
    "bedroom": {
      "scene": "res://scenes/rooms/room_bedroom.tscn",
      "doors": {
        "door_back": "main_hall"
      }
    },
    "basement": {
      "scene": "res://scenes/rooms/room_basement.tscn",
      "doors": {
        "door_up": "main_hall",
        "door_forest_path": "highway"
      }
    },
    "highway": {
      "scene": "res://scenes/rooms/room_highway.tscn",
      "doors": {
        "door_continue": "forest"
      }
    },
    "forest": {
      "scene": "res://scenes/rooms/room_forest.tscn",
      "doors": {}
    }
  }
}
```

- [ ] **Step 3: Open Godot editor — rename/rewire door nodes in room_main_hall.tscn**

In Godot editor, open `scenes/rooms/room_main_hall.tscn`:
- Find the door node that was `door_right` (previously led to corridor) → rename to `door_basement`
- If no basement door exists yet, add a `Door` node (`scenes/objects/door.tscn`) and set `door_id = "door_basement"` in its exported property
- Confirm bedroom door node has `door_id = "door_bedroom"` (was `door_left`)
- Remove any door node referencing `door_entrance` or `door_right` to corridor

In `scenes/rooms/room_basement.tscn`:
- Add a door trigger `door_forest_path` at the far right (hidden until earring collected)

- [ ] **Step 4: Commit**

```bash
git add data/room_graph.json _legacy/
git commit -m "refactor: archive corridor/entrance/storage rooms, simplify room graph to 5 locations"
```

---

### Task 2: Rewrite `data/dialogues/notes.json`

**Files:**
- Rewrite: `data/dialogues/notes.json`

- [ ] **Step 1: Replace the entire `notes.json`**

All keys renamed from `aiyyna` → `kydaana`. All texts verbatim from design doc. Bull name "Хара" → "Дохсун". All "Сардаана" → "Кыдаана".

```json
{
  "note_kydaana_1": [
    {"speaker": "Записка", "text": "Постучали поздно. За дверью стоял старик в драном тарбагане, борода в инее. Просил ночлега."},
    {"speaker": "Записка", "text": "Отец сказал: «Иди в улус, у нас лишних шкур нет». Старик не ответил. Только посмотрел — долго, прямо в глаза отцу. И ушёл в метель."},
    {"speaker": "Записка", "text": "Мать после этого три ночи не спала. Говорила — нельзя было отказывать. Я тогда не поняла, о чём она."}
  ],
  "note_kydaana_2": [
    {"speaker": "Записка", "text": "Они ушли вдвоём на рассвете. Отец и Ньургун. Я давала им хлеб в дорогу — Ньургун улыбнулся, сказал: «К вечеру вернёмся, заплету тебе косу заново»."},
    {"speaker": "Записка", "text": "Отец вернулся один. Руки его дрожали. Он не смог сказать сразу — стоял у порога и смотрел в пол."},
    {"speaker": "Записка", "text": "Сказал — выстрелил, не разглядев. Лес стал пустой, мы голодаем третий месяц, а в кустах что-то двинулось. Он не знал, что Ньургун зашёл с другой стороны."},
    {"speaker": "Записка", "text": "Я верю ему. Это страшнее, чем не верить."}
  ],
  "note_kydaana_3": [
    {"speaker": "Записка", "text": "Мать слегла после первого снега. Шаман из соседнего улуса приехал, посмотрел, ничего не сказал. Только собрал свои бубны и уехал быстрее, чем приехал."},
    {"speaker": "Записка", "text": "Она угасала тихо. Перед смертью взяла мою руку и прошептала: «Это всё за ту ночь, доченька. За того старика. Прости меня, что не настояла»."},
    {"speaker": "Записка", "text": "Я не поняла. Тогда — ещё не поняла."}
  ],
  "note_kydaana_4": [
    {"speaker": "Записка", "text": "Отец вырастил его из телёнка. Кормил с руки. Назвал — Дохсун."},
    {"speaker": "Записка", "text": "После той охоты отец стал тише воды. Почти не выходил, не ел толком. Когда наконец пошёл к загону — будто впервые за зиму выпрямил спину."},
    {"speaker": "Записка", "text": "Я смотрела в окно. Дохсун ждал его у изгороди. Спокойно ждал. А потом — будто кто-то шепнул быку на ухо."},
    {"speaker": "Записка", "text": "Я выбежала, но было поздно. Снег под отцом был красным до самой изгороди."},
    {"speaker": "Записка", "text": "Наайда выла всю ночь. Я не могла плакать."}
  ],
  "note_kydaana_5": [
    {"speaker": "Записка", "text": "Я осталась одна. Наайда не отходит. Дом стал тихим — даже ветер обходит его стороной, будто боится."},
    {"speaker": "Записка", "text": "Я больше не выхожу за порог. Незачем."},
    {"speaker": "Записка", "text": "Если кто-то найдёт это — знай: я не больна. Я просто устала ждать, когда меня заберут следом. Может, так быстрее."},
    {"speaker": "Записка", "text": "Бабка моя говорила — душа уходит туда, куда её зовут. Меня уже давно зовут."},
    {"speaker": "Записка", "text": "(дальше — несколько строк выцвели от времени)"}
  ],
  "note_mother_1": [
    {"speaker": "Дневник", "text": "Хомус починила сегодня — Кыдаана попросила. Восьмой год ей, а пальцы уже ловкие, как у меня в её возрасте."}
  ],
  "note_mother_2": [
    {"speaker": "Дневник", "text": "Муж второй вечер сидит у камелька молча. Говорит — соболя нет, белки нет. Лес опустел. Не знаю, чем его утешить."}
  ],
  "note_mother_3": [
    {"speaker": "Дневник", "text": "Ньургун снова заходил. Принёс рыбы — мужу даже отдал часть улова, сказал «не убудет». Хороший парень. Я вижу, как смотрит на дочь — и она на него. Скоро надо будет говорить с его родителями."}
  ],
  "note_mother_4": [
    {"speaker": "Дневник", "text": "Сегодня уронила нож остриём вниз — воткнулся в пол. Бабка моя говорила: к гостю с дурными вестями. Я весь день не отхожу от окна."}
  ],
  "note_father_1": [
    {"speaker": "Записка охотника", "text": "Соболь — 1. Белка — 3. Заяц — 0."},
    {"speaker": "Записка охотника", "text": "Третью неделю пусто. Капканы холодные."}
  ],
  "note_father_2": [
    {"speaker": "Записка охотника", "text": "Ходил к старому ручью — следов нет. Снег нетронут, будто зверь обошёл нашу землю стороной."},
    {"speaker": "Записка охотника", "text": "Жена не спрашивает, но я вижу — считает запасы."}
  ],
  "note_father_3": [
    {"speaker": "Записка охотника", "text": "Ньургун предложил пойти вместе на дальний кряж. Парень добрый, делится последним. Завидую его терпению — у меня уже руки трясутся, когда лук поднимаю."}
  ],
  "note_father_4": [
    {"speaker": "Записка охотника", "text": "(последняя запись, неровным почерком)"},
    {"speaker": "Записка охотника", "text": "Завтра с Ньургуном на кряж. Только бы хоть что-то взять. Только бы хоть что-то."}
  ],
  "note_env_1": [
    {"speaker": "Надпись", "text": "На притолоке вырезаны слова, уже потемневшие: «Эбэ, хаан буолуой». Чтобы духи предков берегли этот порог."}
  ],
  "note_env_2": [
    {"speaker": "Метка на луке", "text": "Вырезано: «1934. Белка — 40. Соболь — 12». Хороший год. Последняя хорошая зима."}
  ],
  "note_env_3": [
    {"speaker": "Обрывок бересты", "text": "«Сусун. Я не забыл. Верну после охоты — обещаю». Подписи нет. Охота, видно, не вернула."}
  ],
  "note_env_4": [
    {"speaker": "Список", "text": "На полке — лист с колонкой: мука, соль, сало, вяленое мясо. Большинство строк перечёркнуто. Последние три — нет. Но и они кончились давно."}
  ],
  "note_env_5": [
    {"speaker": "Рисунок на бересте", "text": "Чья-то детская рука изобразила дом, собаку, солнце. Внизу — кривые буквы: «Кыдаана». Первое слово, которое она научилась писать."}
  ],
  "artifact_amulet": [
    {"speaker": "Записка при амулете", "text": "Эту косточку мать бабушки нашла на берегу Лены в год, когда пришла большая вода. Она велела хранить её, бабушка передала матери, мать — мне."},
    {"speaker": "Записка при амулете", "text": "В день, когда я родилась, бабушка вложила её мне в пелёнки и сказала: «Носи её — и пусть твоя дорога будет долгой». Я не понимала этих слов. Теперь понимаю."}
  ],
  "artifact_doll": [
    {"speaker": "Записка при кукле", "text": "Мать сшила её сама — из обрезков шёлка, которые берегла с девичества. Я назвала её Уйбаан. Мать смеялась и говорила, что это мужское имя. Я не соглашалась."},
    {"speaker": "Записка при кукле", "text": "После смерти матери я долго не могла взять куклу в руки. Пахла мамой."}
  ],
  "artifact_earring": [
    {"speaker": "Записка при серёжке", "text": "Ньургун нашёл её у старого ювелира в улусе и три месяца откладывал деньги с охоты. Когда протянул мне — смотрел в сторону, щёки красные. Я смеялась."},
    {"speaker": "Записка при серёжке", "text": "Потом плакала — уже одна. Серёжка одна — вторую я так и не нашла. Наверное, осталась там, в лесу. Вместе с ним."}
  ],
  "riddle_kamyolk": [
    {"speaker": "Загадка", "text": "«Красная лисица из норы выглядывает, белые щёки лижет — никто не перечит. Спит — погаснет, кормят — растёт.»"}
  ],
  "riddle_cradle": [
    {"speaker": "Загадка", "text": "«Качаюсь — не падаю, пою — не устаю, держу — не отпускаю, расту — да на месте стою.»"}
  ],
  "riddle_mirror": [
    {"speaker": "Царапина на раме", "text": "«В тихой воде живу, никогда не пью. Смотришь — гляжу обратно, отвернёшься — пропаду без следа.»"},
    {"speaker": "Царапина на раме", "text": "Я любила смотреть в него, когда носила серёжки Ньургуна. Теперь зеркало разбито. И серёжка одна."}
  ],
  "poem_ritual": [
    {"speaker": "", "text": "На камельке нацарапаны слова:"},
    {"speaker": "", "text": "Что укрыло меня, едва свет увидала,\nЧто баюкало в дни, как ходить я училась,\nЧто зажглось, когда сердце забилось чужим —\nВ том порядке огню и отдай.\nИначе балаган возьмёт тебя за свой."}
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add data/dialogues/notes.json
git commit -m "content: rewrite notes.json — Кыдаана/Ньургун/Дохсун/Наайда, verbatim design-doc texts"
```

---

### Task 3: Rewrite `data/dialogues/chapter2_balagan.json`

**Files:**
- Rewrite: `data/dialogues/chapter2_balagan.json`

- [ ] **Step 1: Replace file**

Remove "Айыына" speaker references. Fix room description in `wake_up`. Remove unused legacy flashbacks.

```json
{
  "wake_up": [
    {"speaker": "", "text": "Темно."},
    {"speaker": "", "text": "Запах дыма и чего-то старого — дерева, пропитанного временем."},
    {"speaker": "", "text": "Очаг горит, но тепло не доходит."},
    {"speaker": "", "text": "Балаган. Якутская зимовка. Кто-то жил здесь."},
    {"speaker": "", "text": "Собака у окна — большая, северная. Без ошейника. Смотрит на тебя и уходит в тень."},
    {"speaker": "", "text": "На столе — записка. На полке — старые вещи."},
    {"speaker": "", "text": "Слева — дверь в спальню. В полу — люк в подвал."},
    {"speaker": "", "text": "Двери не открываются просто так. Что-то их держит."},
    {"speaker": "", "text": "Нужно понять, что здесь произошло."},
    {"speaker": "", "text": "Фонарь мерцает. Масло не вечное."}
  ],
  "spirit_chase": [
    {"speaker": "", "text": "Прячься."},
    {"speaker": "", "text": "Она видит."}
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add data/dialogues/chapter2_balagan.json
git commit -m "content: rewrite chapter2_balagan.json — remove Айыына speaker, fix wake_up room desc"
```

---

### Task 4: Fix note references in room scripts

**Files:**
- Modify: `scripts/rooms/room_main_hall_logic.gd`
- Modify: `scripts/rooms/room_bedroom_logic.gd`
- Modify: `scripts/rooms/room_basement_logic.gd`
- Modify: `scripts/rooms/room_forest_logic.gd`
- Rewrite: `scripts/rooms/room_highway_logic.gd`

- [ ] **Step 1: Fix `room_main_hall_logic.gd`**

Change node name lookup and dialogue key for Кыдаана's note 1. Find the block that connects NoteAiyyna1:

```gdscript
# OLD (around line 61):
var note1 := get_node_or_null("NoteAiyyna1")
if note1:
    note1.examined.connect(func(): DialogueManager.start_dialogue("notes/note_aiyyna_1"))
```

Replace with:

```gdscript
var note1 := get_node_or_null("NoteKydaana1")
if not note1:
    note1 = get_node_or_null("NoteAiyyna1")  # fallback for old scene node name
if note1:
    note1.examined.connect(func(): DialogueManager.start_dialogue("notes/note_kydaana_1"))
```

Also update poem_ritual key (already correct) and riddle_kamyolk (rename riddle_kamylok → riddle_kamyolk already OK):
- In `_on_kamylok_examined()`, all DialogueManager.show_text() calls stay the same
- In ritual result check, the correct order is already `["amulet", "doll", "earring"]` — no change needed

- [ ] **Step 2: Fix `room_bedroom_logic.gd`**

Update the note array so old key names have fallbacks, and point riddle to new key:

```gdscript
extends Node2D

func _ready() -> void:
    if GameManager.artifacts_collected.has("doll"):
        for node_name in ["KeyPickable", "ChestDoll", "DollPickable"]:
            var n := get_node_or_null(node_name)
            if n:
                n.queue_free()
        return

    var riddle := get_node_or_null("RiddleCradle")
    if not riddle:
        riddle = get_node_or_null("RiddleBishik")
    if riddle:
        riddle.examined.connect(func(): DialogueManager.start_dialogue("notes/riddle_cradle"))

    var cradle := get_node_or_null("Cradle")
    if not cradle:
        cradle = get_node_or_null("Bishik")
    if cradle:
        cradle.examined.connect(_on_cradle_examined)

    var chest := get_node_or_null("ChestDoll")
    if chest:
        chest.item_used.connect(_on_chest_used)

    var doll := get_node_or_null("DollPickable")
    if doll:
        doll.picked_up.connect(func(_id): _on_doll_picked_up())

    for note_data: Array in [
            ["NoteMother1", "notes/note_mother_1"],
            ["NoteMother2", "notes/note_mother_2"],
            ["NoteMother3", "notes/note_mother_3"],
            ["NoteMother4", "notes/note_mother_4"],
            ["NoteKydaana3", "notes/note_kydaana_3"],
            ["NoteAiyyna3",  "notes/note_kydaana_3"]]:
        var note := get_node_or_null(note_data[0])
        var key: String = note_data[1]
        if note:
            note.examined.connect(func(): DialogueManager.start_dialogue(key))
            break  # only connect first match for kydaana3 fallback pair

func _on_cradle_examined() -> void:
    DialogueManager.show_text("", "Старая колыбель. Крышка закрыта. На стенке — нацарапаны символы.")
    await DialogueManager.dialogue_finished
    DialogueManager.show_text("", "Под покрывалом — что-то твёрдое. Но крышка не поддаётся просто так.")

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

> Note: `_on_cradle_examined()` will be expanded in Task 7 when the minigame is added.

- [ ] **Step 3: Fix `room_basement_logic.gd`**

```gdscript
extends Node2D

func _ready() -> void:
    if GameManager.artifacts_collected.has("earring"):
        for node_name in ["KeyPickable", "ChestEarring", "EarringPickable"]:
            var n := get_node_or_null(node_name)
            if n:
                n.queue_free()
        var door := get_node_or_null("DoorForestPath")
        if door:
            door.visible = true
            door.set_deferred("monitoring", true)
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

    for note_data: Array in [
            ["NoteKydaana5", "notes/note_kydaana_5"],
            ["NoteAiyyna5",  "notes/note_kydaana_5"]]:
        var note := get_node_or_null(note_data[0])
        var key: String = note_data[1]
        if note:
            note.examined.connect(func(): DialogueManager.start_dialogue(key))
            break

func _on_mirror_examined() -> void:
    DialogueManager.show_text("", "Старое зеркало разбито. Осколки рассыпались по рамке. Будто кто-то ударил изнутри.")
    await DialogueManager.dialogue_finished
    DialogueManager.show_text("", "На раме — царапина. Кто-то написал что-то пальцем.")

func _on_chest_used() -> void:
    var earring := get_node_or_null("EarringPickable")
    if earring:
        earring.visible = true
        earring.set_deferred("monitoring", true)

func _on_earring_picked_up() -> void:
    GameManager.collect_artifact("earring")
    _unlock_forest_path()
    _trigger_flashback()

func _unlock_forest_path() -> void:
    var door := get_node_or_null("DoorForestPath")
    if door:
        door.visible = true
        door.set_deferred("monitoring", true)

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

> Note: `_on_mirror_examined()` will be replaced in Task 8 to launch the minigame overlay.

- [ ] **Step 4: Fix `room_forest_logic.gd`**

Change note keys from aiyyna → kydaana, and add missing notes (father_3 is in highway now, forest gets kydaana_2 + env notes):

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

    for note_data: Array in [
            ["NoteFatherLast", "notes/note_father_4"],
            ["NoteKydaana2",   "notes/note_kydaana_2"],
            ["NoteAiyyna2",    "notes/note_kydaana_2"],
            ["NoteEnv2",       "notes/note_env_2"]]:
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
    DialogueManager.show_text("", "Наайда... Она здесь? Откуда?")
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

- [ ] **Step 5: Rewrite `room_highway_logic.gd`**

Was: show highway_arrival dialogue (archived). Now: тропа к лесу с записками отца.

```gdscript
extends Node2D

static var _intro_shown: bool = false

func _ready() -> void:
    var zone := get_node_or_null("TriggerZone")
    if zone:
        zone.body_entered.connect(_on_zone_entered)

    if not _intro_shown:
        _intro_shown = true
        await get_tree().process_frame
        await get_tree().process_frame
        DialogueManager.show_text("", "Тропа уходит в лес. Следы на снегу. Старые — но чьи?")

    for note_data: Array in [
            ["NoteFather1", "notes/note_father_1"],
            ["NoteFather2", "notes/note_father_2"],
            ["NoteFather3", "notes/note_father_3"],
            ["NoteEnv3",    "notes/note_env_3"]]:
        var note := get_node_or_null(note_data[0])
        var key: String = note_data[1]
        if note:
            note.examined.connect(func(): DialogueManager.start_dialogue(key))

func _on_zone_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        GameManager.change_room("door_continue")
```

- [ ] **Step 6: Commit**

```bash
git add scripts/rooms/
git commit -m "content: fix note keys kydaana/father, rewrite highway as forest path"
```

---

## PHASE 2 — Interaction Highlight UI

---

### Task 5: Add interaction highlight ring to player

**Files:**
- Modify: `scripts/player/player.gd`

The player already tracks `nearest_interactable`. We add a single world-space `Sprite2D` (the ring) that follows it.

- [ ] **Step 1: Add a ring Sprite2D as child of player in Godot editor**

In Godot editor, open `scenes/player/player.tscn`:
- Add child `Sprite2D` named `InteractionRing`
- Set texture: a simple white circle/ring PNG (create one via Godot's `ImageTexture` or import a ring.png). Alternatively, use a `StyleBoxFlat` ring via a `ColorRect` — but `Sprite2D` is simpler.
- Set `modulate = Color(1, 1, 1, 0.0)` (starts invisible)
- Set `z_index = 10` so it renders above objects

- [ ] **Step 2: Add `InteractionLabel` Label node**

In the same player scene, add a `Label` named `InteractionLabel`:
- Text: `"[E]"`
- `modulate = Color(1, 1, 1, 0.0)` (starts invisible)
- Position: slightly above InteractionRing

- [ ] **Step 3: Update `scripts/player/player.gd`**

Add these lines to `_ready()` and `_check_interaction()`:

```gdscript
# Add at top of script, with other @onready vars:
@onready var interaction_ring: Sprite2D = $InteractionRing
@onready var interaction_label: Label = $InteractionLabel

# Replace _check_interaction() entirely:
func _check_interaction() -> void:
    if ray.is_colliding():
        var collider := ray.get_collider()
        if collider and collider.has_method("get_interaction_type"):
            nearest_interactable = collider
            prompt.visible = false  # hide old prompt
            interaction_ring.global_position = collider.global_position
            interaction_label.global_position = collider.global_position + Vector2(0, -40)
            interaction_ring.modulate.a = 0.85
            interaction_label.modulate.a = 0.85
            return
    nearest_interactable = null
    interaction_ring.modulate.a = 0.0
    interaction_label.modulate.a = 0.0
```

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player.gd scenes/player/player.tscn
git commit -m "feat: interaction highlight ring + E label on nearest interactable"
```

---

## PHASE 3 — Minigames

---

### Task 6: Create sliding tile minigame (Пятнашки — Cradle)

**Files:**
- Create: `scripts/minigames/minigame_cradle.gd`
- Create: `scenes/minigames/minigame_cradle.tscn`

The minigame is a 4×4 sliding puzzle (15-puzzle). Tiles are Panel nodes with Label children showing carved symbols. One slot is always empty (blank). Player clicks a tile adjacent to blank → tile slides into blank slot. Win when arrangement matches `SOLVED_STATE`.

- [ ] **Step 1: Create `scripts/minigames/minigame_cradle.gd`**

```gdscript
class_name MinigameCradle
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const GRID_SIZE: int = 4
const TILE_SIZE: int = 80
const TILE_GAP: int = 4
const SYMBOLS: Array[String] = [
    "❄", "✦", "◈", "⬡",
    "◉", "✧", "⬢", "◆",
    "✶", "◇", "⬟", "✦",
    "◈", "❄", "✧", ""
]

# Position 15 (index 14 in 0-based = last) is blank in solved state
# solved_state[i] = symbol that should be at grid position i
const SOLVED_STATE: Array[int] = [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,-1]
# -1 = blank tile

var _tiles: Array[int] = []  # current arrangement: _tiles[grid_pos] = symbol_index
var _blank_pos: int = 15     # grid position of blank tile
var _tile_buttons: Array[Button] = []
var _can_interact: bool = true

@onready var _grid_container: GridContainer = $Background/GridContainer
@onready var _close_btn: Button = $Background/CloseBtn

func _ready() -> void:
    _close_btn.pressed.connect(_on_close_pressed)
    _shuffle_tiles()
    _build_grid()

func _shuffle_tiles() -> void:
    _tiles.clear()
    for i in range(GRID_SIZE * GRID_SIZE):
        _tiles.append(i if i < GRID_SIZE * GRID_SIZE - 1 else -1)
    _blank_pos = GRID_SIZE * GRID_SIZE - 1
    # Perform valid shuffle (only legal moves to guarantee solvability)
    var rng := RandomNumberGenerator.new()
    rng.randomize()
    for _i in range(200):
        var neighbors := _get_adjacent_to_blank()
        var pick: int = neighbors[rng.randi() % neighbors.size()]
        _swap_with_blank(pick)

func _build_grid() -> void:
    for child in _grid_container.get_children():
        child.queue_free()
    _tile_buttons.clear()

    _grid_container.columns = GRID_SIZE
    for pos in range(GRID_SIZE * GRID_SIZE):
        var btn := Button.new()
        btn.custom_minimum_size = Vector2(TILE_SIZE, TILE_SIZE)
        var sym_idx: int = _tiles[pos]
        btn.text = SYMBOLS[sym_idx] if sym_idx >= 0 else ""
        btn.disabled = (sym_idx == -1)
        btn.pressed.connect(_on_tile_pressed.bind(pos))
        _grid_container.add_child(btn)
        _tile_buttons.append(btn)

func _on_tile_pressed(pos: int) -> void:
    if not _can_interact:
        return
    if not _is_adjacent_to_blank(pos):
        return
    _swap_with_blank(pos)
    _refresh_grid()
    if _check_solved():
        _on_solved()

func _is_adjacent_to_blank(pos: int) -> bool:
    return pos in _get_adjacent_to_blank()

func _get_adjacent_to_blank() -> Array[int]:
    var result: Array[int] = []
    var row: int = _blank_pos / GRID_SIZE
    var col: int = _blank_pos % GRID_SIZE
    if row > 0: result.append(_blank_pos - GRID_SIZE)
    if row < GRID_SIZE - 1: result.append(_blank_pos + GRID_SIZE)
    if col > 0: result.append(_blank_pos - 1)
    if col < GRID_SIZE - 1: result.append(_blank_pos + 1)
    return result

func _swap_with_blank(pos: int) -> void:
    _tiles[_blank_pos] = _tiles[pos]
    _tiles[pos] = -1
    _blank_pos = pos

func _refresh_grid() -> void:
    for pos in range(_tile_buttons.size()):
        var btn: Button = _tile_buttons[pos]
        var sym_idx: int = _tiles[pos]
        btn.text = SYMBOLS[sym_idx] if sym_idx >= 0 else ""
        btn.disabled = (sym_idx == -1)

func _check_solved() -> bool:
    for i in range(_tiles.size()):
        if _tiles[i] != SOLVED_STATE[i]:
            return false
    return true

func _on_solved() -> void:
    _can_interact = false
    _close_btn.disabled = true
    # Show win animation then emit
    var tween := create_tween()
    tween.tween_property($Background, "modulate", Color(1.5, 1.5, 1.5), 0.4)
    tween.tween_property($Background, "modulate", Color(1, 1, 1), 0.4)
    await tween.finished
    await get_tree().create_timer(0.8).timeout
    minigame_completed.emit("cradle")
    queue_free()

func _on_close_pressed() -> void:
    minigame_cancelled.emit()
    queue_free()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_close_pressed()
        get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Create `scenes/minigames/minigame_cradle.tscn` in Godot editor**

Scene structure:
```
MinigameCradle (CanvasLayer, layer=10) — script: minigame_cradle.gd
  Background (ColorRect, color=Color(0,0,0,0.85), anchors fill screen)
    Title (Label, text="Расставь символы по порядку")
    GridContainer (GridContainer) — positioned center screen
    CloseBtn (Button, text="Закрыть [ESC]") — bottom right
```

- [ ] **Step 3: Integrate minigame into bedroom — update `_on_cradle_examined()`**

In `scripts/rooms/room_bedroom_logic.gd`, change `_on_cradle_examined()`:

```gdscript
var _cradle_minigame_active: bool = false

func _on_cradle_examined() -> void:
    if _cradle_minigame_active:
        return
    DialogueManager.show_text("", "Загадка нацарапана над колыбелью.")
    await DialogueManager.dialogue_finished
    DialogueManager.start_dialogue("notes/riddle_cradle")
    await DialogueManager.dialogue_finished
    _launch_cradle_minigame()

func _launch_cradle_minigame() -> void:
    _cradle_minigame_active = true
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("freeze"):
        player.freeze()

    var scene := preload("res://scenes/minigames/minigame_cradle.tscn")
    var mg: MinigameCradle = scene.instantiate()
    get_tree().current_scene.add_child(mg)
    mg.minigame_completed.connect(_on_cradle_solved)
    mg.minigame_cancelled.connect(_on_cradle_cancelled)

func _on_cradle_solved(_id: String) -> void:
    _cradle_minigame_active = false
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("unfreeze"):
        player.unfreeze()
    DialogueManager.show_text("", "Колыбель качнулась сама. Тихий звук — будто кто-то напевает. Под подушкой что-то блеснуло.")
    await DialogueManager.dialogue_finished
    var key := get_node_or_null("KeyPickable")
    if key:
        key.visible = true
        key.set_deferred("monitoring", true)

func _on_cradle_cancelled() -> void:
    _cradle_minigame_active = false
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("unfreeze"):
        player.unfreeze()
```

- [ ] **Step 4: Commit**

```bash
git add scripts/minigames/minigame_cradle.gd scenes/minigames/ scripts/rooms/room_bedroom_logic.gd
git commit -m "feat: sliding tile minigame (Пятнашки) for cradle puzzle in bedroom"
```

---

### Task 7: Create mirror shard minigame

**Files:**
- Create: `scripts/minigames/minigame_mirror.gd`
- Create: `scenes/minigames/minigame_mirror.tscn`

Puzzle: N shard pieces scattered. Player drags them into matching slots in a frame silhouette. On win: mirror "heals" → shows image → floorboard hint.

- [ ] **Step 1: Create `scripts/minigames/minigame_mirror.gd`**

```gdscript
class_name MinigameMirror
extends CanvasLayer

signal minigame_completed(minigame_id: String)
signal minigame_cancelled()

const SHARD_COUNT: int = 7
const SNAP_DISTANCE: float = 40.0

var _placed_count: int = 0
var _dragging_shard: Control = null
var _drag_offset: Vector2 = Vector2.ZERO
var _can_interact: bool = true

@onready var _frame: Control = $Background/MirrorFrame
@onready var _shards_container: Control = $Background/ShardsContainer
@onready var _reveal_panel: Control = $Background/RevealPanel
@onready var _close_btn: Button = $Background/CloseBtn

func _ready() -> void:
    _reveal_panel.visible = false
    _close_btn.pressed.connect(_on_close_pressed)
    _spawn_shards()

func _spawn_shards() -> void:
    var slots := _frame.get_children()  # Slot0..Slot6 — pre-placed in scene
    # Shards are pre-placed in _shards_container as Panel children
    for i in range(min(SHARD_COUNT, slots.size())):
        var shard: Control = _shards_container.get_child(i)
        shard.set_meta("target_slot_index", i)
        shard.set_meta("is_placed", false)
        shard.gui_input.connect(_on_shard_input.bind(shard))

func _on_shard_input(event: InputEvent, shard: Control) -> void:
    if not _can_interact:
        return
    if shard.get_meta("is_placed", false):
        return
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT:
            if mb.pressed:
                _dragging_shard = shard
                _drag_offset = shard.global_position - mb.global_position
            else:
                _try_snap_shard(shard)
                _dragging_shard = null

func _process(_delta: float) -> void:
    if _dragging_shard:
        _dragging_shard.global_position = get_viewport().get_mouse_position() + _drag_offset

func _try_snap_shard(shard: Control) -> void:
    var target_index: int = shard.get_meta("target_slot_index", -1)
    if target_index < 0:
        return
    var slots := _frame.get_children()
    if target_index >= slots.size():
        return
    var slot: Control = slots[target_index]
    var dist: float = shard.global_position.distance_to(slot.global_position)
    if dist <= SNAP_DISTANCE:
        shard.global_position = slot.global_position
        shard.set_meta("is_placed", true)
        _placed_count += 1
        _check_solved()
    # If not close enough, shard stays where released (player can retry)

func _check_solved() -> void:
    if _placed_count >= SHARD_COUNT:
        _on_solved()

func _on_solved() -> void:
    _can_interact = false
    _close_btn.disabled = true
    # Animate mirror healing
    var tween := create_tween()
    tween.tween_property(_frame, "modulate", Color(1.5, 1.5, 2.0), 0.6)
    tween.tween_property(_frame, "modulate", Color(1, 1, 1), 0.6)
    await tween.finished
    await get_tree().create_timer(0.5).timeout
    # Show reveal image (floorboard with distinctive knot)
    _reveal_panel.visible = true
    await get_tree().create_timer(3.0).timeout
    minigame_completed.emit("mirror")
    queue_free()

func _on_close_pressed() -> void:
    minigame_cancelled.emit()
    queue_free()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_cancel"):
        _on_close_pressed()
        get_viewport().set_input_as_handled()
```

- [ ] **Step 2: Create `scenes/minigames/minigame_mirror.tscn` in Godot editor**

Scene structure:
```
MinigameMirror (CanvasLayer, layer=10) — script: minigame_mirror.gd
  Background (ColorRect, color=Color(0,0,0,0.9), anchors fill screen)
    Title (Label, text="Собери зеркало")
    MirrorFrame (Control, center of screen)
      Slot0..Slot6 (Control nodes — empty slot positions, visible outlines)
    ShardsContainer (Control)
      Shard0..Shard6 (Panel nodes — randomized starting positions, each has distinct color tint)
    RevealPanel (ColorRect + Label, hidden, shown on win)
      Label: "Под третьей доской от окна — там, где сучок похож на звезду."
    CloseBtn (Button, text="Закрыть [ESC]")
```

For visual setup:
- `MirrorFrame`: a rounded rectangle outline (StyleBoxFlat, hollow)
- Each Slot: a small panel with dashed border  
- Each Shard: a Panel with unique color (tinted versions of mirror grey) + unique shape via `StyleBoxFlat.corner_radius_*` settings
- Shards are scattered randomly in ShardsContainer (set positions in editor)

- [ ] **Step 3: Update `_on_mirror_examined()` in `room_basement_logic.gd`**

```gdscript
var _mirror_minigame_active: bool = false
var _mirror_solved: bool = false

func _on_mirror_examined() -> void:
    if _mirror_minigame_active:
        return
    if _mirror_solved:
        DialogueManager.show_text("", "Зеркало собрано. Ты помнишь — третья доска от окна, где сучок звездой.")
        return
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
    mg.minigame_completed.connect(_on_mirror_solved)
    mg.minigame_cancelled.connect(_on_mirror_cancelled)

func _on_mirror_solved(_id: String) -> void:
    _mirror_minigame_active = false
    _mirror_solved = true
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("unfreeze"):
        player.unfreeze()
    DialogueManager.show_text("", "Зеркало собралось. В нём — отражение другого подвала. Там, где сучок в доске похож на звезду, что-то спрятано.")
    await DialogueManager.dialogue_finished
    # Reveal the floorboard interactable
    var floorboard := get_node_or_null("SecretFloorboard")
    if floorboard:
        floorboard.visible = true
        floorboard.set_deferred("monitoring", true)

func _on_mirror_cancelled() -> void:
    _mirror_minigame_active = false
    var player := get_tree().get_first_node_in_group("player")
    if player and player.has_method("unfreeze"):
        player.unfreeze()
```

> Note: In Godot editor, add an `Examinable` node named `SecretFloorboard` to `room_basement.tscn`. Set it initially hidden (`visible = false`, `monitoring = false`). When examined, it uses existing usable/pickable logic to find the key for the chest.

- [ ] **Step 4: Commit**

```bash
git add scripts/minigames/minigame_mirror.gd scenes/minigames/ scripts/rooms/room_basement_logic.gd
git commit -m "feat: mirror shard assembly minigame + basement integration"
```

---

## PHASE 4 — Spirit & Flashlight

---

### Task 8: Add boost mode to `flashlight.gd`

The existing "crank" action (hold F) becomes "boost mode" — brighter cone, faster drain. The QTE system is kept but becomes unreachable from spirit (spirit no longer calls `start_qte()`).

**Files:**
- Modify: `scripts/player/flashlight.gd`

- [ ] **Step 1: Add boost constants and state**

```gdscript
# Add after existing constants:
const BOOST_DRAIN_RATE := 6.0         # drains faster than normal 2.2
const BOOST_ENERGY_MULTIPLIER := 3.5  # much brighter
const BOOST_SCALE_MULTIPLIER := 2.2   # wider/longer cone

var is_boost_active: bool = false
```

- [ ] **Step 2: Replace crank() and stop_crank() with boost equivalents**

```gdscript
func activate_boost() -> void:
    if is_scripted_off or is_qte_active:
        return
    is_boost_active = true
    is_cranking = false  # stop any crank

func deactivate_boost() -> void:
    is_boost_active = false

# Keep crank() and stop_crank() for backward compatibility but redirect:
func crank() -> void:
    activate_boost()

func stop_crank() -> void:
    deactivate_boost()
```

- [ ] **Step 3: Update `_process()` to handle boost drain**

```gdscript
func _process(delta: float) -> void:
    if is_scripted_off:
        energy = 0.0
        return

    if is_qte_active:
        _process_qte(delta)
        return

    if is_boost_active:
        charge = maxf(charge - BOOST_DRAIN_RATE * delta, 0.0)
    elif not is_cranking:
        charge = maxf(charge - DRAIN_RATE * delta, 0.0)

    _update_visuals(delta)

    if charge <= 0.0:
        is_boost_active = false
        charge_depleted.emit()
```

- [ ] **Step 4: Update `_update_visuals()` to show boost cone**

```gdscript
func _update_visuals(delta: float) -> void:
    var charge_ratio := charge / MAX_CHARGE
    if is_boost_active and charge > 0.0:
        energy = _base_energy * BOOST_ENERGY_MULTIPLIER
        texture_scale = _base_scale * BOOST_SCALE_MULTIPLIER
    else:
        energy = _base_energy * charge_ratio
        texture_scale = _base_scale * (0.65 + 0.35 * charge_ratio)

    if charge < LOW_CHARGE and not is_boost_active:
        _flicker_timer -= delta
        if _flicker_timer <= 0.0:
            _flicker_timer = randf_range(0.1, 0.4)
            if randf() < FLICKER_CHANCE:
                energy *= randf_range(0.2, 0.8)
```

- [ ] **Step 5: Commit**

```bash
git add scripts/player/flashlight.gd
git commit -m "feat: flashlight boost mode (hold F = bright cone + faster drain)"
```

---

### Task 9: Rewrite `spirit_guardian.gd` (hold-F banish, 3m min distance)

Removes QTE mechanic entirely. Spirit now retreats when player holds boost (F) in its direction for 1.5s at 3–8m range. Minimum approach distance 3m (≈150px).

**Files:**
- Rewrite: `scripts/characters/spirit_guardian.gd`

- [ ] **Step 1: Write the new spirit script**

```gdscript
class_name SpiritGuardian
extends CharacterBody2D

signal banished()

const PATROL_SPEED := 25.0
const CHASE_SPEED := 45.0
const MIN_DISTANCE := 150.0        # never closer than this (px)
const BANISH_RANGE_MAX := 400.0    # bright light only banishes within this range
const HOLD_TIME_TO_BANISH := 1.5   # seconds of bright light needed
const ALERT_TIME := 2.0
const GRAVITY := 600.0
const FLEE_SPEED := 80.0           # speed when retreating from flashlight

enum State { PATROL, ALERT, CHASE, RETREATING, BANISHED }

@export var patrol_points: Array[Vector2] = []

var state: State = State.PATROL
var current_patrol_index: int = 0
var alert_timer: float = 0.0
var bright_light_timer: float = 0.0   # accumulates while player holds boost
var player_ref: CharacterBody2D = null

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

func _ready() -> void:
    modulate = Color(0.15, 0.08, 0.25, 0.65)
    detection_area.body_entered.connect(_on_body_entered)
    detection_area.body_exited.connect(_on_body_exited)
    if patrol_points.is_empty():
        patrol_points = [global_position + Vector2(-80, 0), global_position + Vector2(80, 0)]

func _physics_process(delta: float) -> void:
    if state == State.BANISHED:
        return

    if not is_on_floor():
        velocity.y += GRAVITY * delta

    match state:
        State.PATROL:    _patrol(delta)
        State.ALERT:     _alert(delta)
        State.CHASE:     _chase(delta)
        State.RETREATING: _retreat(delta)

    _check_bright_light(delta)
    move_and_slide()

func _patrol(_delta: float) -> void:
    var target: Vector2 = patrol_points[current_patrol_index]
    var dir: float = sign(target.x - global_position.x)
    velocity.x = dir * PATROL_SPEED
    sprite.flip_h = dir < 0
    if abs(global_position.x - target.x) < 5.0:
        current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _alert(delta: float) -> void:
    velocity.x = 0
    alert_timer -= delta
    if alert_timer <= 0:
        state = State.CHASE if (player_ref and _player_visible()) else State.PATROL

func _chase(_delta: float) -> void:
    if not player_ref:
        state = State.PATROL
        return
    if player_ref.is_hiding:
        state = State.PATROL
        player_ref = null
        return

    var dist := global_position.distance_to(player_ref.global_position)

    # Maintain minimum distance
    if dist < MIN_DISTANCE:
        state = State.RETREATING
        return

    var dir: float = sign(player_ref.global_position.x - global_position.x)
    velocity.x = dir * CHASE_SPEED
    sprite.flip_h = dir < 0

func _retreat(_delta: float) -> void:
    # Move away from player until MIN_DISTANCE restored
    if not player_ref:
        state = State.PATROL
        return
    var dist := global_position.distance_to(player_ref.global_position)
    if dist >= MIN_DISTANCE + 20.0:
        state = State.CHASE
        return
    var dir: float = -sign(player_ref.global_position.x - global_position.x)
    velocity.x = dir * FLEE_SPEED
    sprite.flip_h = dir < 0

func _check_bright_light(delta: float) -> void:
    if state == State.BANISHED or not player_ref:
        bright_light_timer = 0.0
        return

    var fl = _get_player_flashlight()
    if not fl:
        bright_light_timer = 0.0
        return

    var dist := global_position.distance_to(player_ref.global_position)
    var in_banish_range := dist >= MIN_DISTANCE and dist <= BANISH_RANGE_MAX
    var boost_on: bool = fl.is_boost_active and fl.charge > 0.0
    var in_light_cone: bool = _is_in_flashlight_cone(fl)

    if boost_on and in_banish_range and in_light_cone:
        bright_light_timer += delta
        # Slow down while being illuminated
        velocity.x *= 0.4
        if bright_light_timer >= HOLD_TIME_TO_BANISH:
            _initiate_banish()
    else:
        bright_light_timer = maxf(bright_light_timer - delta * 0.5, 0.0)

func _is_in_flashlight_cone(fl: Node) -> bool:
    if not player_ref:
        return false
    # Spirit is in cone if on the same horizontal side as player is facing
    var facing_right: bool = fl.scale.x > 0
    var spirit_is_right: bool = global_position.x > player_ref.global_position.x
    return facing_right == spirit_is_right

func _get_player_flashlight() -> Node:
    if not player_ref:
        return null
    return player_ref.get_node_or_null("Flashlight")

func _on_body_entered(body: Node2D) -> void:
    if body is CharacterBody2D and body.has_method("freeze") and not body.is_in_group("spirit"):
        if body.is_hiding:
            return
        player_ref = body as CharacterBody2D
        if state == State.PATROL:
            state = State.ALERT
            alert_timer = ALERT_TIME

func _on_body_exited(body: Node2D) -> void:
    if body == player_ref and state == State.ALERT:
        state = State.PATROL
        player_ref = null

func _player_visible() -> bool:
    return player_ref != null and not player_ref.is_hiding

func _initiate_banish() -> void:
    state = State.BANISHED
    velocity = Vector2.ZERO
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, 0.8)
    await tween.finished
    banished.emit()
    queue_free()
```

- [ ] **Step 2: Add `"spirit"` group to spirit scene**

In Godot editor, open `scenes/characters/spirit_guardian.tscn`:
- Select root node → Groups → add group `"spirit"`

- [ ] **Step 3: Commit**

```bash
git add scripts/characters/spirit_guardian.gd scenes/characters/spirit_guardian.tscn
git commit -m "feat: rewrite spirit — hold-F banish (1.5s), 3m min distance, no QTE"
```

---

## PHASE 5 — Polish

---

### Task 10: Note counter in main menu

**Files:**
- Modify: `scripts/autoload/game_manager.gd` (add note tracking)
- Modify: `scripts/ui/main_menu.gd`

Notes found are tracked in `GameManager`. The save system already persists `GameManager` state.

- [ ] **Step 1: Add note tracking to `game_manager.gd`**

```gdscript
# Add to GameManager's variable list:
var notes_found: Array[String] = []

const TOTAL_NOTES: int = 18

func mark_note_found(note_id: String) -> void:
    if not notes_found.has(note_id):
        notes_found.append(note_id)
        SaveManager.autosave()
```

- [ ] **Step 2: Call `mark_note_found()` from examinable note nodes**

In `scripts/objects/examinable.gd`, after triggering dialogue, emit note found. Since examinables already connect to `examined` signal, the room logic scripts can call `GameManager.mark_note_found(note_id)` in their lambdas. Example pattern for room scripts:

```gdscript
# In room logic _ready(), replace anonymous lambda with:
if note1:
    note1.examined.connect(func():
        DialogueManager.start_dialogue("notes/note_kydaana_1")
        GameManager.mark_note_found("note_kydaana_1")
    )
```

Apply this pattern to all 18 note connections across all room scripts.

- [ ] **Step 3: Update `main_menu.gd` to show note counter**

```gdscript
extends Control

func _ready() -> void:
    $Buttons/ContinueBtn.disabled = not SaveManager.has_save()
    _update_note_counter()
    $Buttons/NewGameBtn.pressed.connect(_on_new_game_pressed)
    $Buttons/ContinueBtn.pressed.connect(_on_continue_pressed)
    $Buttons/SettingsBtn.pressed.connect(_on_settings_pressed)
    $Buttons/QuitBtn.pressed.connect(_on_quit_pressed)
    $Buttons/NewGameBtn.grab_focus()

func _update_note_counter() -> void:
    var count: int = GameManager.notes_found.size()
    var total: int = GameManager.TOTAL_NOTES
    var label := get_node_or_null("NoteCounterLabel")
    if label:
        label.text = "Записки: %d / %d" % [count, total]
```

> Note: In Godot editor, add a `Label` named `NoteCounterLabel` to `scenes/ui/main_menu.tscn`.

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/game_manager.gd scripts/ui/main_menu.gd scenes/ui/main_menu.tscn
git commit -m "feat: note counter in main menu (N/18 found)"
```

---

### Task 11: Verify finale dialogue

**Files:**
- Read: `data/dialogues/finale.json`
- Read: `scripts/rooms/finale.gd`

- [ ] **Step 1: Check finale.json against design-doc verbatim dialogue**

Open `data/dialogues/finale.json`. The good-ending dialogue must match exactly:

```
"Ты услышал меня. Спустя столько зим — кто-то наконец услышал.
Меня звали Кыдаана. Я не успела сказать это никому, кроме матери и Ньургуна. А теперь — и тебе."
[Наайда подходит, толкает носом в руку]
"Она ждала со мной. Все эти годы. Теперь — пойдёт со мной туда, где светло."
"Уходи из этого дома, пока огонь не догорел. И не возвращайся. Пусть он осыпется и зарастёт травой — так будет правильно."
"Спасибо тебе. Иди."
```

If any "Айыына" or "Сардаана" appears in finale.json — replace with "Кыдаана".

- [ ] **Step 2: Check finale.gd for bad ending — confirm save wipe**

`finale.gd` must erase the save on bad ending. Confirm the logic:

```gdscript
# In bad ending completion handler — must call:
SaveManager.delete_save()
GameManager.artifacts_collected.clear()
GameManager.notes_found.clear()
GameManager.loop_state = 0
```

If missing, add these calls before returning to main menu.

- [ ] **Step 3: Commit if changes needed**

```bash
git add data/dialogues/finale.json scripts/rooms/finale.gd
git commit -m "content: verify finale — Кыдаана verbatim dialogue, save wipe on bad ending"
```

---

## Self-Review Checklist

**Spec coverage:**
- ✅ Archive corridor/entrance/storage → _legacy (Task 1)
- ✅ room_graph.json 5-room (Task 1)
- ✅ All 18 notes, verbatim text, correct names (Task 2)
- ✅ chapter2_balagan.json fix (Task 3)
- ✅ All room scripts: note key renames + fallbacks (Task 4)
- ✅ Interaction highlight ring + E label (Task 5)
- ✅ Cradle sliding tile minigame (Task 6)
- ✅ Mirror shard minigame (Task 7)
- ✅ Flashlight boost mode (Task 8)
- ✅ Spirit hold-F banish, 3m min (Task 9)
- ✅ Note counter in main menu (Task 10)
- ✅ Finale verbatim + save wipe (Task 11)
- ⚠️ **Spirit chapter distribution** (1/2/3): not scripted in plan — handled in Godot editor by placing 1 SpiritGuardian in main_hall scene, 2 in bedroom, up to 3 in forest. No script change needed.
- ⚠️ **5 env note texts** (env_1–5): included in notes.json (Task 2). **Needs user approval before committing.** Show them during Task 2 execution.
- ⚠️ **Oil lamp refill**: design doc mentions refilling flashlight at лампы in safe rooms. Not in this plan — add an `OilLamp` Usable node to main_hall and bedroom scenes in editor. Script: `GameManager` or room logic calls `flashlight.charge = flashlight.MAX_CHARGE` on examine.

**Placeholder scan:** None found.

**Type consistency:**
- `MinigameCradle` uses `signal minigame_completed(minigame_id: String)` — bedroom connects `_on_cradle_solved(_id: String)` ✅
- `MinigameMirror` uses same signal pattern — basement connects `_on_mirror_solved(_id: String)` ✅
- `SpiritGuardian._get_player_flashlight()` returns `Node` and accesses `fl.is_boost_active` — this property is added to `Flashlight` class in Task 8 ✅
- `GameManager.mark_note_found()` called in Task 10 — method added in same task ✅
