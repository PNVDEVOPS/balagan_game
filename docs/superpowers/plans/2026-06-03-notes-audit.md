# Notes Audit & Rewiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Удалить орфанные/неканоничные ключи и узлы записок, починить дубли, привести тексты к компендиуму.

**Architecture:** Loader — явная таблица в room-logic GD скриптах → `DialogueManager.start_dialogue("notes/key")` → `data/dialogues/notes.json`.

**Tech Stack:** Godot 4.3+, GDScript, JSON, tscn

---

### Task 1: Удалить note_env_1 и note_env_2 из JSON

**Files:**
- Modify: `data/dialogues/notes.json`

- [ ] Удалить ключ `"note_env_1"` вместе со значением
- [ ] Удалить ключ `"note_env_2"` вместе со значением

### Task 2: Удалить note_haryshal и заменить entry_c4

**Files:**
- Modify: `data/dialogues/notes.json`
- Modify: `scripts/rooms/room_corridor_logic.gd:107-112`

- [ ] В room_corridor_logic.gd: entry_c1 → убрать case (note_key останется ""), узел освободится сам (queue_free)
- [ ] В room_corridor_logic.gd: entry_c4 → `note_key = "artifact_amulet"`
- [ ] Удалить ключ `"note_haryshal"` из notes.json

### Task 3: Удалить NoteEnv1 из сцены и логики зала

**Files:**
- Modify: `scenes/rooms/room_main_hall.tscn:78-81`
- Modify: `scripts/rooms/room_main_hall_logic.gd:73-83`

- [ ] Удалить узел NoteEnv1 из room_main_hall.tscn
- [ ] Убрать `["NoteEnv1", ...]` из for-loop в room_main_hall_logic.gd

### Task 4: Очистить inline examine_text у NoteEnv5

**Files:**
- Modify: `scenes/rooms/room_main_hall.tscn:85`

- [ ] `examine_text = "Дом. Собака. ..."` → `examine_text = ""`
  (JSON — источник истины; inline дублирует и мёртв из-за is_active)

### Task 5: Удалить осиротевший узел NoteAiyyna3

**Files:**
- Modify: `scenes/rooms/room_bedroom.tscn:100-102`

- [ ] Удалить блок NoteAiyyna3

### Task 6: Починить note_father_4 (ремарка почерка)

**Files:**
- Modify: `data/dialogues/notes.json`

- [ ] `"(последняя запись, неровным почерком)"` → `"(почерк неровный)"`

---

**Не требуют правок (уже верно):**
- Шаг 2 (NoteEntry1 → note_env_hunting): работает
- Шаг 5 (NoteEnv3 → note_env_4): работает
- Шаг 9: все канонические записки размещены

**Замечание (Шаг 10):** riddle_kamyolk / riddle_cradle / riddle_mirror дублируют загадку из artifact_amulet/doll/earring — это задумано. Правка текста загадки требует синхронной правки в обоих местах.
