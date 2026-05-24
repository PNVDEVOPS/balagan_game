# Design: Viewport Fix, Remove ExamineWindow, Polish Zones
**Date:** 2026-05-24

## 1. Viewport Fix

**Problem:** Camera2D in player.tscn has no limits. Player walks at y=640, viewport height=360px, so camera shows y=460–820. Trees (y=338–640) are above the view; lower half of screen shows black.

**Fix:** Set `limit_bottom = 700` on Camera2D in `scenes/player/player.tscn`. With the player at y=640 and limit_bottom=700, Godot clamps the camera so its bottom edge stays at y=700 — camera shows y=340–700. Trees, sky, and floor all visible.

## 2. Remove ExamineWindow Mechanic

**Problem:** Complex popup with title/view/description used for 8+ interactables. User wants simpler flow — just character dialogue.

**What changes:**
- All `preload("res://scenes/ui/examine_window.tscn").instantiate()` + `.open()` / `.open_jumpscare()` calls replaced with `DialogueManager.show_text("", "...")`.
- Jumpscare silhouette effect removed entirely (no replacement).
- `scenes/ui/examine_window.tscn` and `scripts/ui/examine_window.gd` deleted.

**Files to update:** room_highway_logic.gd, room_forest_logic.gd, room_bedroom_logic.gd, room_closet_logic.gd, room_corridor_logic.gd, room_dining_logic.gd, room_kydaana_logic.gd, room_main_hall_logic.gd.

**FamilyPhoto:** Remove node from `scenes/rooms/room_bedroom.tscn`, remove handler `_on_family_photo_examined` from `scripts/rooms/room_bedroom_logic.gd`.

## 3. Simple Window Examinables

Add `Examinable` nodes (using existing examinable.tscn) at window positions in indoor rooms. No popup — just `examine_text` triggers `DialogueManager.show_text` via existing examinable logic.

| Room | Node name | examine_text |
|------|-----------|-------------|
| Спальня | WindowBedroom | «За окном — метель. Деревья согнулись. Как мы выберемся отсюда?» |
| Коридор | WindowCorridor | «Черно. Только снег мельтешит в свете луны.» |
| Столовая | WindowDining | «Двор занесло. Забор накренился под снегом.» |
| Вход/Entry | WindowEntry | «Дорога едва видна. Следы уже занесло.» |

Position each node near existing window visual elements in the respective scene.

## 4. Polish Zones

### Highway (room_highway) — 1800 → 2400px

- Background, RoadSurface, FloorVisual extend to x=2400
- Add road dashes: CenterLineDash7 (x=1821–1881), CenterLineDash8 (x=2121–2181)
- Add trees: TreeRight6 (x=1921), TreeRight7 (x=2221)
- Move SnowSign: x=900 → x=1400
- Move NarrativeTrigger: x=1400 → x=1800
- Move TriggerZone: x=1770 → x=2370
- Move RoomRight marker: x=1800 → x=2400

### Forest Trail (room_forest) — 2400 → 3200px

- Background, SnowGround, FloorVisual, PathLight extend to x=3200
- Add 2–3 more trees in the new space (x=2200–3000)
- Spread notes:
  - NoteForestFather: x=500 → x=600
  - BrokenBranch: x=700 → x=950
  - NoteAiyyna2: x=1000 → x=1300
  - OldFireplace: x=1200 → x=1700
  - NoteFatherLast: x=1500 → x=2100
  - ShamanAmulet: x=1800 → x=2500
  - BalaganSign: x=2100 → x=2900
- Move Balagan building: x=2196–2396 → x=2880–3080
- Move BalaganLight accordingly
- Move LaikaTrigger: x=1460 → x=2000
- Move Laika: x=1600 → x=2150
- Move ExitZone: x=2330 → x=3130
- Move RoomRight marker: x=2400 → x=3200
- Move LeftWall stays at x=-20 (unchanged)
