# Handoff — Балаган

_Последнее обновление: 2026-05-26_

---

## Лор проекта

- **Игра**: «Балаган» — хоррор-приключение от первого лица (2D платформер/ходилка)
- **Семья**: якутская, зажиточная, начало 1900-х. Отец — мясник и охотник. Постепенно беднели из-за уменьшения дичи.
- **Протагонист**: русский мужчина средних лет, приехал в начале 2000-х. Тексты от его лица — взгляд человека из 2000-х на дом начала века.
- Все examine-тексты должны отражать этот контраст.

---

## Текущий стек

| Параметр | Значение |
|---|---|
| Движок | Godot 4.6 (GL Compatibility) |
| Язык | GDScript |
| Viewport | 640×360, растягивается до 1920×1080 |
| Главная сцена | `scenes/ui/main_menu.tscn` |

### Автолоады
- `GameManager` — глобальное состояние игры
- `Inventory` — инвентарь
- `AudioManager` — звук
- `DialogueManager` — показ текста (используется вместо ExamineWindow)
- `SaveManager` — сохранения
- `ChapterManager` — прогресс по главам
- `SubtitleManager` — субтитры

### Input map
- `move_left/right` — A/D и стрелки
- `run` — Shift
- `interact` — E
- `hide` — Q
- `inventory` — Tab / I
- `advance_dialogue` — Space / Enter
- `crank` — F

---

## Архитектура

### Ключевые системы
- **Examinable** (`scripts/objects/examinable.gd`, `scenes/objects/examinable.tscn`) — осмотр объектов. Вызывает `DialogueManager.show_text()`. ExamineWindow **удалён** полностью.
- **Interactable** (`scripts/objects/interactable.gd`) — взаимодействуемые объекты
- **Door** (`scripts/objects/door.gd`) — переходы между комнатами
- **Player** (`scripts/player/player.gd`, `scenes/player/player.tscn`) — персонаж
- **Flashlight** (`scripts/player/flashlight.gd`) — фонарик

### Сцены комнат (актуальные)
```
scenes/rooms/
  room_main_hall.tscn    — главный зал
  room_bedroom.tscn      — спальня
  room_corridor.tscn     — коридор
  room_dining.tscn       — столовая
  room_entry.tscn        — вход
  room_storage.tscn      — кладовая
  room_closet.tscn       — чулан
  room_basement.tscn     — подвал
  room_kydaana.tscn      — кыдааны (?)
  room_highway.tscn      — трасса (внешняя локация)
  room_forest.tscn       — тропа в лесу (внешняя локация)
  room_finale.tscn       — финал
```

`_legacy/` — старые сцены, не используются.

---

## Контекст последней сессии (2026-05-24)

### Что сделано
- **Camera2D limit_bottom=700** — деревья и небо видны (y=340–700 в кадре)
- **ExamineWindow удалён** — popup-окна заменены на `DialogueManager.show_text()`. Файлы `examine_window.tscn` и `examine_window.gd` удалены. Джамспкеры (силуэты) убраны.
- **Семейное фото** убрано из спальни (FamilyPhoto нода и хендлер удалены)
- **Простые Examinable-ноды** добавлены в спальню, коридор, столовую, вход — разные фразы от персонажа
- **room_highway** расширена до 2400px: SnowSign → x=1400, нарративный триггер → x=1800, выход-зона → x=2370, добавлены 2 дерева и дорожные линии
- **room_forest** расширена до 3200px: записки через ~400px, балаган → x=2880, лайка и триггер → x=2000/2150, добавлены 2 дерева

### Активные задачи
- Визуальные фоны для трассы и тропы — пользователь рисует сам
- Тексты записок и дополнительные examinable-объекты — по ситуации

---

## Известные костыли / нюансы

- Сцены в `_legacy/` сохранены на случай, если понадобится вернуть что-то
- `scenes/objects/highway_parallax_background.tscn` + `highway_parallax_background.gd` — отдельный параллакс для трассы
- `scenes/rooms/parallax_layer_3.gd` — отдельный скрипт для слоя параллакса леса
