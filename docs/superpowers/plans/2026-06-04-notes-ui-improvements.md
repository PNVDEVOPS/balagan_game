# Notes UI Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix five issues: note popup too small; other controls fire while popup open; E key advances only once in multi-page notes; flashlight loses charge permanently after boost; add a notes journal next to the inventory.

**Architecture:** All changes touch existing scripts and scenes. A new `notes_journal_ui.gd / .tscn` is created and added to `hud.tscn` as a sibling of `InventoryUI`. No new autoloads. Journal reads `GameManager.notes_found` and re-opens notes via the existing `DialogueManager.start_dialogue()` path.

**Tech Stack:** Godot 4.3, GDScript, existing textures (`assets/ui/notes/note_*.png`, `assets/ui/inv_bag.png`)

---

## File Map

| Action  | Path |
|---------|------|
| Modify  | `scripts/ui/note_popup.gd` |
| Modify  | `scripts/player/player.gd` |
| Modify  | `scripts/ui/inventory_ui.gd` |
| Modify  | `scripts/ui/hud.gd` |
| Modify  | `scripts/player/flashlight.gd` |
| Modify  | `scenes/ui/inventory_ui.tscn` |
| Modify  | `scenes/ui/hud.tscn` |
| Create  | `scripts/ui/notes_journal_ui.gd` |
| Create  | `scenes/ui/notes_journal_ui.tscn` |

---

## Task 1 — Fix "E advances once then breaks" bug

**Root cause:** `player.gd._unhandled_input` runs before `NotePopup._unhandled_input` (leaf nodes process first in `_unhandled_input` bottom-up order). The player calls `DialogueManager.advance()` which sees `current_lines` empty → sets `is_active = false`. From that point on, E goes to the `interact` branch instead of the popup, re-opening the note from page 1.

**Files:**
- Modify: `scripts/ui/note_popup.gd` — add public `is_open` property
- Modify: `scripts/player/player.gd` — skip `DialogueManager.advance()` while note is open

---

- [ ] **Step 1.1 — Add `is_open` property to `note_popup.gd`**

In `scripts/ui/note_popup.gd`, after the `var _is_open: bool = false` line (line 29), add:

```gdscript
var is_open: bool:
	get: return _is_open
```

Full context after edit — lines 27-31 should read:
```gdscript
var _lines: Array = []
var _index: int = 0
var _is_open: bool = false
var is_open: bool:
	get: return _is_open
```

- [ ] **Step 1.2 — Guard `DialogueManager.advance()` call in `player.gd`**

In `scripts/player/player.gd`, find `_unhandled_input` (line 86). Replace:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	# Dialogue advancement always works, even while frozen
	if DialogueManager.is_active:
		if event.is_action_pressed("advance_dialogue"):
			DialogueManager.advance()
		return
```

With:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	# Dialogue advancement always works, even while frozen
	if DialogueManager.is_active:
		if event.is_action_pressed("advance_dialogue") and not NotePopup.is_open:
			DialogueManager.advance()
		return
```

- [ ] **Step 1.3 — Verify in game**

Run the game. Find a multi-page note (e.g. `note_kydaana_1` in the entry room — 3 pages). Press E:
- Page 1 → page 2 ✓
- Page 2 → page 3 ✓
- Page 3 → popup closes ✓
- Pressing E again on the same note re-opens from page 1 ✓

- [ ] **Step 1.4 — Commit**

```
git add scripts/ui/note_popup.gd scripts/player/player.gd
git commit -m "fix: note popup E key — guard DialogueManager.advance() while NotePopup open"
```

---

## Task 2 — Increase note popup size

**Files:**
- Modify: `scripts/ui/note_popup.gd`

---

- [ ] **Step 2.1 — Increase panel minimum size**

In `scripts/ui/note_popup.gd` `_build_ui()`, line 69:

```gdscript
_panel.custom_minimum_size = Vector2(230, 100)
```

Change to:

```gdscript
_panel.custom_minimum_size = Vector2(400, 180)
```

- [ ] **Step 2.2 — Increase text area minimum size**

Line 90:

```gdscript
_text.custom_minimum_size = Vector2(178, 40)
```

Change to:

```gdscript
_text.custom_minimum_size = Vector2(340, 100)
```

- [ ] **Step 2.3 — Verify in game**

Open any note with long text (e.g. `note_kydaana_3` — 5 pages of long lines). Confirm text is not cut off. Confirm the paper texture fills the larger area without distortion.

- [ ] **Step 2.4 — Commit**

```
git add scripts/ui/note_popup.gd
git commit -m "fix: note popup size 230x100 -> 400x180 to fit longer text"
```

---

## Task 3 — Block inventory and pause during popup

**Files:**
- Modify: `scripts/ui/inventory_ui.gd`
- Modify: `scripts/ui/hud.gd`

---

- [ ] **Step 3.1 — Block inventory toggle while popup is open**

In `scripts/ui/inventory_ui.gd`, find `_unhandled_input` (line 26). Replace:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		toggle()
```

With:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active:
		return
	if event.is_action_pressed("inventory"):
		toggle()
```

- [ ] **Step 3.2 — Block pause (Esc) while popup is open**

In `scripts/ui/hud.gd`, find `_unhandled_input` (line 16). Replace:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pm: Control = $PauseMenu
		if pm.visible:
			pm.hide()
			get_tree().paused = false
		else:
			pm.show()
			get_tree().paused = true
		get_viewport().set_input_as_handled()
```

With:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if DialogueManager.is_active:
			get_viewport().set_input_as_handled()
			return
		var pm: Control = $PauseMenu
		if pm.visible:
			pm.hide()
			get_tree().paused = false
		else:
			pm.show()
			get_tree().paused = true
		get_viewport().set_input_as_handled()
```

- [ ] **Step 3.3 — Verify in game**

Open a note popup. While it's visible:
- Press I (inventory) — inventory should NOT open ✓
- Press Esc — pause menu should NOT open ✓
- Player should stand still ✓

Close the popup, confirm inventory and pause still work normally.

- [ ] **Step 3.4 — Commit**

```
git add scripts/ui/inventory_ui.gd scripts/ui/hud.gd
git commit -m "fix: block inventory and pause input while note popup is open"
```

---

## Task 4 — Fix flashlight charge loss after boost

**Problem:** `activate_boost()` drains `charge` at `BOOST_DRAIN_RATE = 7.0/sec`. When charge hits 0, `is_boost_active = false` but charge stays at 0. Subsequent boosts have no effect. Fix: restore `charge = MAX_CHARGE` whenever boost ends (both on key-release and on charge-depletion).

**Files:**
- Modify: `scripts/player/flashlight.gd`

---

- [ ] **Step 4.1 — Restore charge when boost deactivates via key release**

In `scripts/player/flashlight.gd`, find `deactivate_boost()` (line 141). Replace:

```gdscript
func deactivate_boost() -> void:
	is_boost_active = false
```

With:

```gdscript
func deactivate_boost() -> void:
	is_boost_active = false
	charge = MAX_CHARGE
```

- [ ] **Step 4.2 — Restore charge when boost drains to zero**

In `_process()`, find the boost section (lines 92-95):

```gdscript
	if is_boost_active:
		charge = maxf(charge - BOOST_DRAIN_RATE * delta, 0.0)
		if charge <= 0.0:
			is_boost_active = false
```

Change to:

```gdscript
	if is_boost_active:
		charge = maxf(charge - BOOST_DRAIN_RATE * delta, 0.0)
		if charge <= 0.0:
			is_boost_active = false
			charge = MAX_CHARGE
```

- [ ] **Step 4.3 — Verify in game**

Pick up the flashlight. Hold the crank key until the boost visually dims (charge depletes to 0 and auto-stops). Release the key. Hold crank again — flashlight should boost normally at full brightness. Repeat several times — flashlight should never stay permanently dark.

- [ ] **Step 4.4 — Commit**

```
git add scripts/player/flashlight.gd
git commit -m "fix: restore flashlight charge to MAX after boost ends"
```

---

## Task 5 — Create notes journal UI script and scene

The journal is a CanvasLayer (layer=5) that owns a small icon button and a popup panel. When the button is clicked, the panel rebuilds from `GameManager.notes_found` and shows thumbnail buttons (existing note textures). Clicking a thumbnail closes the panel and re-opens the note via `DialogueManager.start_dialogue()`.

**Files:**
- Create: `scripts/ui/notes_journal_ui.gd`
- Create: `scenes/ui/notes_journal_ui.tscn`

---

- [ ] **Step 5.1 — Create `scripts/ui/notes_journal_ui.gd`**

Create the file with the full content below:

```gdscript
extends CanvasLayer

# Canonical display order — matches notes.json keys.
# Notes not in GameManager.notes_found are silently skipped.
const NOTE_ORDER: Array[String] = [
	"note_kydaana_1", "note_kydaana_2", "note_kydaana_3",
	"note_kydaana_4", "note_kydaana_5",
	"note_mother_1", "note_mother_2", "note_mother_3", "note_mother_4",
	"note_father_1", "note_father_2", "note_father_3", "note_father_4",
	"note_env_4", "note_env_5", "note_env_hunting",
	"artifact_amulet", "artifact_doll", "artifact_earring",
	"riddle_kamyolk", "riddle_cradle", "riddle_mirror",
	"poem_ritual",
]

var _journal_btn: Button
var _panel:       PanelContainer
var _grid:        GridContainer

func _ready() -> void:
	layer = 5
	_build_ui()
	_panel.visible = false

func _build_ui() -> void:
	# ── Journal button (left of bag button) ──────────────────────────────
	_journal_btn = Button.new()
	_journal_btn.offset_left   = 4.0
	_journal_btn.offset_top    = 3.0
	_journal_btn.offset_right  = 26.0
	_journal_btn.offset_bottom = 25.0
	_journal_btn.custom_minimum_size = Vector2(22, 22)
	_journal_btn.focus_mode = Control.FOCUS_NONE
	_journal_btn.flat = true
	_journal_btn.expand_icon = true
	_journal_btn.icon = load("res://assets/ui/notes/note_kydaana.png") as Texture2D
	_journal_btn.pressed.connect(toggle)
	add_child(_journal_btn)

	# ── Panel ─────────────────────────────────────────────────────────────
	_panel = PanelContainer.new()
	_panel.offset_left = 4.0
	_panel.offset_top  = 30.0
	_panel.custom_minimum_size = Vector2(290, 0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.layout_mode = 2
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.layout_mode = 2
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.layout_mode = 2
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = "Записки"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 10)
	title_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.add_theme_font_size_override("font_size", 10)
	close_btn.pressed.connect(func(): _panel.visible = false)
	title_row.add_child(close_btn)

	# Grid (4 columns of note thumbnails)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.layout_mode = 2
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(_grid)

func toggle() -> void:
	if DialogueManager.is_active:
		return
	if _panel.visible:
		_panel.visible = false
	else:
		_rebuild_grid()
		_panel.visible = true

func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var num := 1
	for note_id: String in NOTE_ORDER:
		if GameManager.notes_found.has(note_id):
			_add_entry(num, note_id)
			num += 1

func _add_entry(num: int, note_id: String) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(60, 50)
	btn.flat = true
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE

	var tex := TextureRect.new()
	tex.texture = load(_texture_path(note_id)) as Texture2D
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.layout_mode = 1
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex)

	var lbl := Label.new()
	lbl.text = str(num)
	lbl.layout_mode = 1
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left   = -16.0
	lbl.offset_top    = -14.0
	lbl.offset_right  = -2.0
	lbl.offset_bottom = -2.0
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	btn.pressed.connect(func():
		_panel.visible = false
		DialogueManager.start_dialogue("notes/" + note_id)
	)
	_grid.add_child(btn)

func _texture_path(note_id: String) -> String:
	if note_id.begins_with("note_mother_"):
		return "res://assets/ui/notes/note_mother.png"
	if note_id.begins_with("note_father_") \
			or note_id == "note_env_4" \
			or note_id == "note_env_hunting":
		return "res://assets/ui/notes/note_father.png"
	return "res://assets/ui/notes/note_kydaana.png"

func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		_panel.visible = false
		get_viewport().set_input_as_handled()
```

- [ ] **Step 5.2 — Create `scenes/ui/notes_journal_ui.tscn`**

Create the file with this minimal content (Godot will fill in the UID on first import):

```
[gd_scene format=3 uid="uid://notes_journal_ui1"]

[ext_resource type="Script" path="res://scripts/ui/notes_journal_ui.gd" id="1"]

[node name="NotesJournalUI" type="CanvasLayer"]
script = ExtResource("1")
```

- [ ] **Step 5.3 — Verify script parses**

Open Godot editor. Check the Output panel — no errors loading `notes_journal_ui.gd`. The scene `notes_journal_ui.tscn` should appear without errors in the FileSystem panel.

- [ ] **Step 5.4 — Commit**

```
git add scripts/ui/notes_journal_ui.gd scenes/ui/notes_journal_ui.tscn
git commit -m "feat: add notes journal UI (script + scene, not yet wired to HUD)"
```

---

## Task 6 — Integrate journal into HUD and shift bag button

The journal button sits at x=4–26 (leftmost). The existing bag button must shift right by 24 px to x=28–50. The InventoryPanel shifts the same 24 px so its slot row still starts where the bag button ends.

**Files:**
- Modify: `scenes/ui/inventory_ui.tscn`
- Modify: `scenes/ui/hud.tscn`

---

- [ ] **Step 6.1 — Shift BagButton right in `inventory_ui.tscn`**

In `scenes/ui/inventory_ui.tscn`, find the `BagButton` node block and change:

```
offset_left = 4.0
offset_right = 26.0
```

To:

```
offset_left = 28.0
offset_right = 50.0
```

- [ ] **Step 6.2 — Shift InventoryPanel right in `inventory_ui.tscn`**

In the same file, find the `InventoryPanel` node block and change:

```
offset_left = 30.0
offset_right = 234.0
```

To:

```
offset_left = 54.0
offset_right = 258.0
```

- [ ] **Step 6.3 — Add `NotesJournalUI` to `hud.tscn`**

In `scenes/ui/hud.tscn`, add a new `ext_resource` entry after the last existing one (currently id="7"):

```
[ext_resource type="PackedScene" uid="uid://notes_journal_ui1" path="res://scenes/ui/notes_journal_ui.tscn" id="8"]
```

Then add a new node entry right after the `InventoryUI` node line:

```
[node name="NotesJournalUI" parent="." instance=ExtResource("8")]
```

The InventoryUI node line currently reads:
```
[node name="InventoryUI" parent="." unique_id=1349982912 instance=ExtResource("2")]
```

Insert the new node line immediately after it.

- [ ] **Step 6.4 — Verify layout in game**

Run the game. In the top-left corner:
- Journal icon (parchment) at far left ✓
- Bag icon 2 px to its right ✓
- Inventory panel appears after the bag ✓
- Clicking journal icon opens the notes panel ✓
- Clicking a found note in the panel opens the note popup (re-read) ✓
- Clicking × or pressing Esc closes the journal panel ✓
- Journal cannot be opened while a note popup is active ✓

- [ ] **Step 6.5 — Commit**

```
git add scenes/ui/inventory_ui.tscn scenes/ui/hud.tscn
git commit -m "feat: wire notes journal into HUD, shift bag button right 24px"
```

---

## Self-Review

### Spec coverage
| Requirement | Task |
|---|---|
| Popup bigger, fits more text | Task 2 |
| Player doesn't move during popup | Already handled by `DialogueManager.is_active` in player.gd — verified in Task 1.3 |
| Other buttons don't fire during popup | Task 3 (inventory + pause) |
| E key works for all pages | Task 1 |
| Notes list near inventory | Tasks 5–6 |
| Clickable note thumbnails (existing textures, no text) | Task 5 `_add_entry()` uses TextureRect with the paper texture only |
| Numbering in journal | Task 5 `_add_entry()` shows number label |
| Journal icon left of bag button | Task 6 |
| Flashlight recovers after boost | Task 4 |

### Notes on `riddle_kamyolk` and `poem_ritual`
These two keys appear in `NOTE_ORDER` but `room_main_hall_logic.gd` does not call `GameManager.mark_note_found()` for them, so they will never appear in the journal as currently coded. This is a separate pre-existing omission in room logic. To fix it, add these two calls to `room_main_hall_logic.gd` alongside the existing `examined.connect` lambdas — out of scope for this plan but noted for the next session.
