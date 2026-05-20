# Балаган — Aggressive Refactor Design Spec
**Date:** 2026-05-20  
**Source docs:** `balagan_game_pitch.md`, `claude_code_rebuild_prompt.md`  
**Approach:** Aggressive refactor + extend. Old code that doesn't fit the new architecture moves to `_legacy/`.

---

## 1. Scope & Constraints

- **Engine:** Godot 4, GDScript typed (`var x: int := 0`)
- **Perspective:** 2D wide panoramic side-scroller (not 3D first-person)
- **Runtime:** 40–60 min playthrough, 3 chapters
- **All character names strictly:** Кыдаана, Ньюргун, Дохсун (бык), Наайда (собака)
- **All note text:** verbatim from `balagan_game_pitch.md` — no paraphrasing
- **Signals, not direct references** between systems
- **No `pass`, no TODO** in production code

---

## 2. What to Keep, Rewrite, Archive

### Keep (clean, fits new design)
- `scripts/autoload/` — all 6 autoloads (game_manager, save_manager, audio_manager, chapter_manager, inventory, dialogue_manager)
- `scripts/objects/` — entire Interactable family (examinable, pickable, usable, door, hideable, interactable base)
- `scripts/player/player.gd` + `flashlight.gd`
- `scenes/ui/` — all UI scenes unchanged
- `assets/sprites/` — player, spirit, laika frames

### Rewrite (wrong content or wrong structure)
- `data/dialogues/notes.json` — all 18 notes rewritten with correct content + names
- `data/dialogues/chapter2_balagan.json` — all "aiyyna"/"Ayiyna" keys → "kydaana"/"Кыдаана"
- `data/dialogues/finale.json` — verify against design doc verbatim dialogue
- `data/dialogues/forest_laika_appears.json` — rewrite for Наайда
- `data/room_graph.json` — 5 canonical locations only
- `scripts/rooms/room_main_hall_logic.gd` — rewrite (has NoteAiyyna1 references)
- `scripts/rooms/room_bedroom_logic.gd` — rewrite + add sliding-tile minigame
- `scripts/rooms/room_basement_logic.gd` — rewrite + add mirror-shard minigame
- `scripts/rooms/room_highway_logic.gd` — rewrite as "тропа" (path to forest)
- `scripts/rooms/room_forest_logic.gd` — rewrite for Ньюргун murder site content
- `scripts/characters/laika.gd` — verify + fix name references (Наайда)
- `scripts/characters/spirit_guardian.gd` — rewrite spirit behavior (see §5)
- `scenes/rooms/room_*.tscn` — content nodes renamed/replaced in all 5 rooms

### Archive to `_legacy/` (do not delete without permission)
- `scenes/rooms/room_corridor.tscn` + `scripts/rooms/room_corridor_logic.gd`
- `scenes/rooms/room_entrance.tscn` + `scripts/rooms/room_entrance_logic.gd`
- `scenes/rooms/room_storage.tscn` + `scripts/rooms/room_storage_logic.gd`
- `data/dialogues/highway_arrival.json`

---

## 3. Room Architecture

### Canonical 5 locations

| Room ID | Scene file | Chapter | Artifact |
|---|---|---|---|
| `main_hall` | `room_main_hall.tscn` | I | Амулет |
| `bedroom` | `room_bedroom.tscn` | II | Тряпичная кукла |
| `basement` | `room_basement.tscn` | III | Серёжка |
| `highway` | `room_highway.tscn` | III transit | — |
| `forest` | `room_forest.tscn` | III | — |
| `finale` | `room_finale.tscn` | — | — |

`room_graph.json` updated to reflect exactly these 6 nodes.

### Room transition rules
- Chapters gate: bedroom unlocks after amulet collected; basement/highway/forest unlock after doll collected.
- `ChapterManager` owns gating logic, not individual rooms.

---

## 4. Data Layer — Notes System

### Structure (stays JSON, compatible with existing DialogueManager)

All 18 notes stored in `data/dialogues/notes.json` under key `"notes"`:

```
notes/note_kydaana_1   — Бродяга (гость у порога)
notes/note_kydaana_2   — Охота (гибель Ньюргуна)
notes/note_kydaana_3   — Мать (болезнь, слова перед смертью)
notes/note_kydaana_4   — Бык (гибель отца)
notes/note_kydaana_5   — Последняя (Кыдаана одна)
notes/diary_mother_1   — Хомус починила
notes/diary_mother_2   — Муж молчит у камелька
notes/diary_mother_3   — Ньюргун заходил, принёс рыбы
notes/diary_mother_4   — Нож упал остриём вниз
notes/hunt_father_1    — Счёт зверя: пусто
notes/hunt_father_2    — Следов нет у ручья
notes/hunt_father_3    — Ньюргун предложил идти вместе
notes/hunt_father_4    — Завтра с Ньюргуном (последняя запись)
notes/env_1            — Надпись-молитва на притолоке
notes/env_2            — Метка на охотничьем луке (год, зверь)
notes/env_3            — Записка о долге соседу (не возвращён)
notes/env_4            — Засохший список запасов (вычеркнутые строки)
notes/env_5            — Детский рисунок с подписью «Кыдаана» (обрывок)

notes/artifact_amulet  — флэшбэк при подборе амулета
notes/artifact_doll    — флэшбэк при подборе куклы
notes/artifact_earring — флэшбэк при подборе серёжки (активирует зеркало)
notes/riddle_kamylok   — загадка у камелька
notes/riddle_cradle    — загадка у колыбели
notes/riddle_mirror    — загадка у зеркала
notes/poem_ritual      — стих на камельке
```

**5 environment notes** (env_1–5): texts written in the design doc's style (short, northern, no pathos). Submitted to user for approval before being committed to code.

### Note UI
- Opened with **Tab** or from pause menu
- List grouped by category: Кыдаана / Мать / Отец / Окружение / Артефакты
- Header shows `Записки: N / 18 собрано`
- All found notes re-readable at any time

---

## 5. Interaction UI

**Highlight circle:** when player's interaction raycast hits an `Interactable`, a circular glow/ring sprite appears centered on the target object.

**E-prompt label:** appears above the highlight with action text (e.g., "Осмотреть", "Поднять", "Открыть").

**Implementation:** `interactable.gd` already has `get_interaction_type()`. The highlight logic lives in `player.gd` — `_check_interaction()` already sets `nearest_interactable`. Add:
- `highlight_ring: Sprite2D` (or `AnimatedSprite2D`) on each Interactable OR a single pooled overlay managed by the player.
- Preferred: **single world-space marker** (`InteractionMarker`) that player repositions over the nearest interactable each frame. No per-object overhead.

---

## 6. Minigames

### 6.1 Камелёк (Зал — already working)
Keep existing fire-lighting logic. Ensure riddle note is displayed before puzzle. Key visible among embers after fire lit.

### 6.2 Колыбель — Пятнашки / Sliding Tile (Спальня)
**Trigger:** player examines cradle → riddle dialogue → minigame opens.  
**Activation note:** `notes/riddle_cradle` displayed first.

**Grid:** 4×4 sliding tile puzzle (15-puzzle). Tiles are carved wooden symbols matching northern motifs (not numbers — avoid meta feel).  
**Goal:** arrange tiles to reveal a complete image (baby in cradle, or the колыбель symbol).  
**Win condition:** tile arrangement matches solved state → cradle rocks animation (2s) → lullaby audio → chest opens → key appears under pillow.  
**UX:** drag or click adjacent-to-blank tile to slide. ESC cancels and returns to room (key not found).

**Scene:** `scenes/minigames/minigame_cradle.tscn`, script `scripts/minigames/minigame_cradle.gd`.  
Minigame is launched as a CanvasLayer overlay, not a scene change. Emits `minigame_completed(minigame_id: String)` signal on win.

### 6.3 Зеркало — Сборка Осколков (Подвал)
**Activation trigger:** player enters basement (Chapter III gating). Mirror is already there, but becomes interactive when player approaches.

**Riddle note:** `notes/riddle_mirror` — placed near the mirror, shown when approaching. Contains both the riddle text AND a one-line reference: *"Я любила смотреть на себя в нём, когда носила серёжки Ньюргуна"* — this line connects mirror → earring narratively without requiring a separate note. Mirror puzzle activates after this note is shown.

**`notes/artifact_earring`** plays as a flashback AFTER the earring is found (not before), as designed.

**Puzzle:** Broken mirror fragments scattered across puzzle area. Player drag-and-drops shards into a silhouette frame. Shards have correct rotation baked in (no rotation mechanic — simpler, less frustrating).  
**Win condition:** all shards placed → mirror "heals" (animation) → mirror surface reveals an image: a floorboard with a distinctive knot/mark.  
**Post-puzzle:** player returns to basement, finds a floorboard with that same knot (highlighted by interaction ring) → examines → earring found.

**Scene:** `scenes/minigames/minigame_mirror.tscn`, script `scripts/minigames/minigame_mirror.gd`.  
Same overlay pattern, same `minigame_completed` signal.

---

## 7. Spirit / Flashlight System

### Behavior (rewrite `spirit_guardian.gd`)
- Spawns via scene trigger or ChapterManager signal
- Patrols predefined waypoints or wanders in radius
- On player detection: approaches slowly, **never closer than 3m** (≈ 150px in 2D)
- If player ignores: spirit circles, applies audio pressure (breathing, creak)
- If player runs or ignores extended time: spirit "flashes" to 3m — game-over trigger (screen black → respawn from autosave)

### Flashlight interaction (existing `flashlight.gd` extended)
- Spirit visible at medium distance as dark blurred silhouette
- **Hold F (bright mode):** if bright cone held on spirit for ≥ 1.5s within range → spirit disappears
- Normal flashlight on spirit: spirit slows but does not vanish
- Spirit within 3m: flashlight F has no effect — must retreat

### Chapter distribution
- Chapter I (main_hall): 1 spirit, 1 scripted encounter at end (tutorial — teaches mechanic)
- Chapter II (bedroom + transit): 2 active spirits
- Chapter III (basement + highway + forest): up to 3 simultaneous in forest

---

## 8. Ritual & Endings (existing, verify content)

### Ritual (main_hall kamylok)
- 3 artifact slots above fireplace
- Sequential artifact placement via inventory select → examine kamylok
- Correct order: амулет → кукла → серёжка (chronological: birth → childhood → love)
- Poem on hearth gives clue (verbatim from design doc)

### Good ending
Verbatim from `balagan_game_pitch.md` "Финальный диалог". Кыдаана appears full-figure, Наайда presses nose to player's hand, both dissolve in light, dawn, door opens, slow white fade → credits.

### Bad ending (PT loop)
1. Artifacts blacken, Кыдаана vanishes silently
2. Наайда stares through player with empty eyes
3. All doors/windows locked
4. Player approaches door → camera forces on gap → player's own figure approaches through snow
5. Figure speaks opening line → player yells (`НЕТ! НЕ ЗАХОДИ!`)
6. Figure steps in → cut to black
7. Return to main menu — "Продолжить" greyed out, save erased

---

## 9. Main Menu Updates

- **Новая игра** / **Продолжить** (greyed if no save or post-bad-ending) / **Настройки** / **Выход**
- Note counter in menu: `Записки: N / 18`
- Aesthetic: dark bg, silhouette of balagan in snow, wind sound + homuz
- Existing `main_menu.tscn` + `main_menu.gd` — refactor to add note counter display

---

## 10. Code Quality Rules

- Typed GDScript everywhere: `var x: int := 0`
- All cross-system communication via signals
- No `pass`, no TODO in production code
- Old code that can't be cleanly integrated → `_legacy/` not patched with hacks
- Each completed stage committed before next stage begins

---

## 11. Open Items (need user approval before coding)

1. **5 environment note texts (env_1–5):** write drafts, show to user for sign-off
2. **Tile image for cradle puzzle:** symbolic image (not numbers) — confirm content
3. **Mirror shard count:** 6–9 pieces recommended for mobile-friendly difficulty
