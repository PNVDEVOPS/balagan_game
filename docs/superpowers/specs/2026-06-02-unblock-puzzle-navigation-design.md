# Design: Unblock Puzzle, Back Navigation, Chapter Fade

**Date:** 2026-06-02  
**Status:** Approved

---

## 1. Unblock Puzzle (MinigameUnblock)

### Overview
A sliding-block puzzle that opens when the player examines the Kamyolk (fireplace) in room_main_hall. The goal: slide firewood blocks out of the way to free the amulet block and reveal it at the base of the stove.

### File
`scripts/minigames/minigame_unblock.gd` — extends CanvasLayer (same pattern as minigame_cradle.gd)

### Grid
- 6×6 cells, each cell ~90px
- One **amulet block**: horizontal 1×2, starts somewhere mid-grid, needs to reach the right edge (exit column 5)
- 6–8 **firewood blocks**: mix of horizontal 1×2 and vertical 2×1, block the path
- Hardcoded layout, solvable in ~4 moves

### Hardcoded layout
Defined as a list of blocks: `[row, col, is_horizontal, length]`. The amulet block is horizontal length-2 on row 2, starting at col 0. Exit is the right edge at row 2. Exact positions chosen during implementation to guarantee ~4-move solution. Must be verified solvable before shipping.

### Controls
- **Mouse:** click a block to select it (highlight), then click the empty cell in its axis to move it there. Or drag.
- **Keyboard:** arrow keys move the selected block one step in its valid axis.

### Visuals
- Dark overlay (Color 0,0,0,0.88)
- Firewood blocks: warm brown rectangles (`Color(0.55, 0.35, 0.15)`)
- Amulet block: golden-amber (`Color(0.85, 0.65, 0.1)`) with label "◈"
- Selected block: slight white outline / brighter modulate
- Exit marker: small arrow or gap on right wall at row 2

### Signals
```gdscript
signal minigame_completed(minigame_id: String)  # emits "unblock"
signal minigame_cancelled()
```
ESC or close button cancels without penalty (puzzle reopens on next examine).

---

## 2. room_main_hall_logic.gd Changes

### Removed
- `_damper_open` variable and all damper logic
- `_on_damper_examined()` function
- `WoodPickable` node handling (firewood is now part of the puzzle, not a pickup)
- `Inventory.has_item("firewood")` check in `_on_kamylok_examined`

### New variable
```gdscript
var _puzzle_solved: bool = false
```

### New flow for `_on_kamylok_examined()`
- **COLD state, puzzle not solved:** short dialogue → open MinigameUnblock
- **COLD state, puzzle solved:** `Inventory.has_item("firewood")` not needed — player can light fire directly (firewood freed by puzzle stays in stove)
- **BURNING / RITUAL_READY / RITUAL_ACTIVE:** unchanged

### After puzzle solved (`_on_puzzle_solved()`)
1. Set `_puzzle_solved = true`
2. Dialogue: "Под золой — что-то блестит."
3. Make `AmuletPickable` visible at stove base position

### `_setup_puzzle()` cleanup
- Remove Damper node on `_ready` (whether or not amulet is done)
- Remove WoodPickable node on `_ready`

---

## 3. chapter_manager.gd Changes

### Removed
- `_title_label` node and all label setup in `_ready()`
- `_show_title()` function
- Call to `_show_title()` in `start_chapter()`

### Result
`start_chapter()` becomes: fade out → change scene → place player → autosave → fade in → emit signal.

---

## 4. Back Navigation

### Corridors — add `door_back` to room_graph.json
Each corridor room gets a `door_back` entry pointing to the previous room:
```json
"entry_c1": { "door_forward": "entry_c2", "door_back": "entry" },
"entry_c2": { "door_forward": "closet",   "door_back": "entry_c1" },
"entry_c3": { "door_forward": "entry_c4", "door_back": "closet" },
"entry_c4": { "door_forward": "main_hall","door_back": "entry_c3" },
"corridor":  { "door_forward": "dining",  "door_back": "main_hall" },
"corridor2": { "door_forward": "corridor3","door_back": "bedroom" },
"corridor3": { "door_forward": "storage", "door_back": "corridor2" }
```
In `room_corridor.tscn`: add `BackZone` Area2D on left edge (mirror of ExitZone).
In `room_corridor_logic.gd`: BackZone fires `GameManager.change_room("door_back")`.

### Loop rooms (entry variants, closet, main_hall, storage)
These rooms loop when going left. Add `door_exit` pointing to self in room_graph.json where missing:
```json
"closet":    { "door_exit": "closet" },
"main_hall": { "door_exit": "main_hall" },
"storage":   { "door_exit": "storage" }
```
(entry, entry2, entry3, entry4 already have `door_exit` defined)

Each loop room scene gets a `BackZone` on left edge that fires `GameManager.change_room("door_exit")`. Before changing room, show character subtitle:
- 1st trigger: "Снова здесь. Что-то не пускает."
- 2nd trigger: "Та же дверь. Тот же коридор."
- 3rd+ trigger: "Я хожу по кругу."
(count stored as a local var per room instance, resets each room load)

### Repeating corridor reaction
- In `room_corridor_logic.gd`, track visit count per room_id in `GameManager` (or local static)
- On second+ entry to same corridor: show subtitle from player
  - Visit 2: "Опять этот коридор."
  - Visit 3+: "Снова и снова. Стены одинаковые."

---

## 5. Kydaana Subtitle Fix

**File:** `scripts/rooms/room_corridor_logic.gd`, line 23

**Change:** `SubtitleManager.Pos.TOP_LEFT` → `SubtitleManager.Pos.TOP_CENTER`

```gdscript
# Before
SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_LEFT)
# After
SubtitleManager.show_subtitle("Уходи.", SubtitleManager.Pos.TOP_CENTER)
```

---

## Files to Create
- `scripts/minigames/minigame_unblock.gd`

## Files to Modify
- `scripts/rooms/room_main_hall_logic.gd`
- `scripts/rooms/room_corridor_logic.gd`
- `scripts/rooms/room_entry_logic.gd`
- `scripts/rooms/room_storage_logic.gd`
- `scripts/autoload/chapter_manager.gd`
- `data/room_graph.json` (add door_back to corridors, door_exit loops to closet/main_hall/storage)
- `scenes/rooms/room_main_hall.tscn` (remove Damper node, reposition AmuletPickable)
- `scenes/rooms/room_corridor.tscn` (add BackZone Area2D on left edge)
- `scenes/rooms/room_entry.tscn` (add BackZone Area2D on left edge)
- `scenes/rooms/room_storage.tscn` (add BackZone Area2D on left edge)
- `scenes/rooms/room_main_hall.tscn` (add BackZone Area2D on left edge)
- `scenes/rooms/room_closet.tscn` (add BackZone Area2D on left edge)
