---
name: project-architecture
description: Ключевые системы, пути к файлам, паттерны — справочник по проекту Балаган
metadata:
  type: project
---

## Диалоги и тексты
- Все реплики/записки: `data/dialogues/notes.json`
- Лесная сцена Лайки: `data/dialogues/forest_laika_appears.json`
- Финал: `data/dialogues/finale.json`
- Глава 2: `data/dialogues/chapter2_balagan.json`
- Инлайн show_text — в `scripts/rooms/room_*_logic.gd`

## Маршрутизация записок
`DialogueManager.start_dialogue("notes/note_mother_X")` → NotePopup (бумага+шрифт)
- `note_mother_*` → записка матери (Caveat, assets/ui/notes/note_mother.png)
- `note_father_*` → записка отца (SegoeScript, assets/ui/notes/note_father.png)
- `note_kydaana_*` → записка Кыдааны (PlaypenSans, assets/ui/notes/note_kydaana.png)
- Остальные → обычный диалоговый бокс

**Why:** Записки должны показываться с бумажным фоном и рукописным шрифтом
**How to apply:** При добавлении новых записок использовать префиксы note_mother_/note_father_/note_kydaana_

## Шрифты
- Georgia: assets/fonts/Georgia-Regular.ttf (основной UI, установлен)
- SegoeScript: assets/fonts/SegoeScript.ttf (скопирован из Windows Fonts)
- Caveat: assets/fonts/Caveat-Regular.ttf (нужно скачать с Google Fonts)
- PlaypenSans: assets/fonts/PlaypenSans-Regular.ttf (нужно скачать с Google Fonts)

## UI панели
- 9-slice текстура: assets/ui/panel_9slice.png (48x48, тайлы 16px)
- texture_margin = 16 во всех StyleBoxTexture
- Аватары: assets/ui/avatars/{player,laika,kydaana}.png

## Минигра (Камелёк)
- Скрипт: scripts/minigames/minigame_klotski.gd (class_name KlotskiPuzzle)
- Победа → queue_free() → room_main_hall_logic._on_puzzle_solved → амулет появляется
- Раскладка: оригинальный Huarong Dao 10 фигур

## Аватары в диалоге
AVATAR_TEXTURES в dialogue_box.gd — ключи lower-case имён спикеров
