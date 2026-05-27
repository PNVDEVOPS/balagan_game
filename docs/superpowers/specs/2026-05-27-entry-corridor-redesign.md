# Spec: Entry + Corridor — Конвертация в формат highway/forest

**Дата:** 2026-05-27

---

## Цель

Переработать `room_entry.tscn` и `room_corridor.tscn` под формат прокручиваемых сцен (как highway/forest): Player в сцене, HUD, Floor с коллизией, Camera2D лимиты. Установить новый маршрут через дом.

---

## Новый маршрут (room_graph.json)

```
entry → entry_c1 → entry_c2 → closet → entry_c3 → entry_c4 → main_hall
         (corr)      (corr)               (corr)      (corr)
```

- `entry_c1`–`entry_c4` — все указывают на `res://scenes/rooms/room_corridor.tscn`
- Существующая цепочка `main_hall → corridor → dining → bedroom → …` не трогается
- Старые `entry2`, `entry3`, `entry4` остаются в файле но больше не задействованы

---

## room_entry.tscn

**Ширина:** 1280px

### Структура (по образцу forest)
| Нода | Тип | Параметры |
|---|---|---|
| Background | ColorRect | 0–1280 × 0–360, цвет `(0.04, 0.02, 0.06)` |
| Player | instance player.tscn | position (80, 290) |
| HUD | instance hud.tscn | — |
| Floor | StaticBody2D + WorldBoundaryShape2D | position y=330 |
| LeftWall | StaticBody2D + RectangleShape2D(40×373) | x=-20 |
| RightWall | StaticBody2D + RectangleShape2D(40×373) | x=1280 |
| SpawnPoint | Marker2D | (80, 290) |
| RoomRight | Marker2D | (1280, 180) |
| RoomBottom | Marker2D | (0, 360) |
| ExitZone | Area2D + RectangleShape2D(60×140) | x=1240 |
| ClothesExaminable | instance examinable.tscn | x=300 |
| WindowEntry | instance examinable.tscn | x=700 |
| LaikaTrigger | Area2D | убрать (Лайка не в entry) |
| Laika | убрать | — |

### Контент
- **ClothesExaminable** `examine_text`: `"Довольно старинного вида одежда."`
- **WindowEntry** `examine_text`: `"Дорога едва видна под снегом. Следы уже замело. Обратного пути нет."`
- Никаких субтитров при входе
- Никаких субтитров при осмотре объектов

---

## room_corridor.tscn

**Ширина:** 1600px

### Структура
| Нода | Тип | Параметры |
|---|---|---|
| Background | ColorRect | 0–1600 × 0–360, цвет `(0.03, 0.02, 0.05)` |
| Player | instance player.tscn | position (80, 290) |
| HUD | instance hud.tscn | — |
| Floor | StaticBody2D + WorldBoundaryShape2D | position y=330 |
| LeftWall | StaticBody2D + RectangleShape2D(40×373) | x=-20 |
| RightWall | StaticBody2D + RectangleShape2D(40×373) | x=1600 |
| SpawnPoint | Marker2D | (80, 290) |
| RoomRight | Marker2D | (1600, 180) |
| RoomBottom | Marker2D | (0, 360) |
| ExitZone | Area2D + RectangleShape2D(60×140) | x=1560 |
| WindowExamine | instance examinable.tscn | x=200 |
| SpiritGuardian | instance spirit_guardian.tscn | x=900, без триггера |
| LaikaTrigger | Area2D + RectangleShape2D(80×160) | x=700 |
| Laika | instance laika.tscn | x=1100, auto_appear=false |

### Контент по room_id

| room_id | Событие | Текст |
|---|---|---|
| `entry_c1` | При входе | — |
| `entry_c1` | Осмотр окна (первый раз) | `"Двор. Снег по колено, ничего не разобрать."` |
| `entry_c1` | Осмотр окна (повторно) | `"..."` |
| `entry_c2` | При входе | — |
| `entry_c2` | Осмотр окна (первый раз) | `"Двор. Снег по колено, ничего не разобрать."` |
| `entry_c2` | Осмотр окна (повторно) | `"..."` |
| `entry_c3` | При входе | Субтитр **"Уходи."** (SubtitleManager) |
| `entry_c3` | Осмотр окна (первый раз) | `"Мне кажется, или кто-то смотрит в ответ из темноты?"` |
| `entry_c3` | Осмотр окна (повторно) | `"..."` |
| `entry_c4` | При входе | — |
| `entry_c4` | LaikaTrigger (один раз) | DialogueManager: `"Опять эта лайка… Возможно, она ведёт меня куда-то?"` |
| `entry_c4` | Осмотр окна | `"Дорога едва видна под снегом. Следы уже замело. Обратного пути нет."` (нет повторного) |

- **SpiritGuardian** — присутствует визуально во всех коридорах, без триггеров и реплик

---

## room_entry_logic.gd

```
_ready():
  - Установить cam.limit_right = 1280 (через Player → Camera2D)
  - Подключить ExitZone.body_entered → _on_exit_zone
  - Подключить ClothesExaminable.examined → examine_text напрямую через examinable (examine_text уже задан в сцене)

_on_exit_zone(body):
  - if player → GameManager.change_room("door_forward")
```

---

## room_corridor_logic.gd

```
_ready():
  - Установить cam.limit_right = 1600 (через Player → Camera2D)
  - Подключить ExitZone.body_entered → _on_exit_zone
  - Настроить WindowExamine.examine_text и повторный осмотр по room_id
  - Если room_id == "entry_c3": SubtitleManager.show_subtitle("Уходи.", TOP_LEFT)
  - Если room_id == "entry_c4": подключить LaikaTrigger → _on_laika_trigger

_on_exit_zone(body):
  - if player → GameManager.change_room("door_forward")

_on_laika_trigger(body):
  - (один раз) laika.appear()
  - DialogueManager.show_text("", "Опять эта лайка… Возможно, она ведёт меня куда-то?")
  - Лайка уходит вправо + fade out (как в forest)
```

**Повторный осмотр окна:** `Examinable` не имеет встроенного счётчика — логика проверяет булеву переменную `_window_examined` и меняет `examine_text` на `"..."` после первого срабатывания сигнала `examined`.

---

## Изменения в room_graph.json

```json
"entry": {
  "scene": "res://scenes/rooms/room_entry.tscn",
  "doors": { "door_forward": "entry_c1" }
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
}
```

---

## Что НЕ меняется

- `room_closet.tscn` и его логика
- `room_main_hall.tscn` и его логика
- Цепочка `main_hall → corridor → dining → bedroom → corridor2 → corridor3 → …`
- `room_bedroom.tscn`, `room_dining.tscn` и пр.
