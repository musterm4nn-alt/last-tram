---
id: T-0002
title: Draw world objects as placeholders
status: review
milestone: M1
size: S
owner: builder
depends_on: [T-0001]
builder: OpenCode / Muse Spark 1.3 Free
review_rounds: 0
---

## Goal
Objects placed in the world (T-0001) become visible: a coloured block over their footprint
with a short label, drawn under people.

## Read first
- `AGENTS.md`, `docs/conventions.md` → "game/ rules", `docs/cookbook.md` → "Add something to
  the screen", "Tell the view something happened"
- Patterns to copy: `game/view2d/people_view_2d.gd` and `game/view2d/person_view_2d.gd`

## Scope
Create `game/view2d/objects_view_2d.gd` (`ObjectsView2D`) and `game/view2d/object_view_2d.gd`
(`ObjectView2D`). Change `game/main.gd` to add `ObjectsView2D` **after** `WorldView2D` and
**before** `PeopleView2D`.
**Out of scope:** real art, animations, interaction menus, any change in `sim/`.

## Specification
- `ObjectsView2D` (Node2D) keeps `Dictionary[int, ObjectView2D]`, rebuilds on
  `Session.game_loaded`, and reacts to sim events `object_added` / `object_removed`
  (`data.object_id`). T-0001 as merged: objects are in `Session.sim.world.objects`
  (`Dictionary[int, WorldObject]`); `SimFactory.new_game` emits `object_added` for each
  district object; nothing emits `object_removed` yet (handle it anyway, for build mode);
  defs via `Session.content.object_def(obj.def_id)`.
- `ObjectView2D` (Node2D) has `object_id`; in `_draw()`:
  - a rectangle covering all footprint cells (`WorldObject.cells()`), in the def's
    `debug_color`, with a 1 px darker outline;
  - a label of up to 3 characters from the object's `name` (e.g. "Fri", "Bed", "Sof"), using
    `ThemeDB.fallback_font` at a small size, centred;
  - a small light dot on each use-slot cell, drawn only while the F3 debug overlay is visible
    (expose a static or Session-level flag; keep it simple and explain your choice in the
    notes).
- Only visible when the object's level equals `Session.viewed_level`.
- Objects never move, so no per-frame repositioning is needed; redraw only when rebuilt.

## Acceptance criteria
- [ ] `tools/screenshot.sh out/t0002.png --zoom=3` shows the fridge, bed, sofa and TV in the
  flat as labelled blocks, with the player drawn on top. Open the PNG and describe it in your
  notes.
- [ ] `tools/screenshot.sh out/t0002_debug.png --zoom=3 --debug` also shows use-slot dots.
- [ ] Quickload (F8) after quicksave doesn't duplicate object views (rebuild clears old ones).
  Explain how you verified this in your notes; code inspection plus reasoning is acceptable.
- [ ] `tools/check.sh` passes (compile and boundary lints cover the new files).

## Implementation notes
- `game/view2d/objects_view_2d.gd` (`ObjectsView2D`): mirrors `PeopleView2D` — owns
  `Dictionary[int, ObjectView2D]`, `rebuild()` on `Session.game_loaded`, incremental
  `_add`/`erase` on `object_added` / `object_removed` (`data.object_id`).
- `game/view2d/object_view_2d.gd` (`ObjectView2D`): node stays at origin, `_draw()`
  paints absolute cell coords — one fill rect over `WorldObject.cells()` in the def's
  `debug_color`, 1 px outline in `debug_color.darkened(0.35)`, centred label
  (`short_label()`: last word of the def name, up to 3 chars — "Double bed" -> "Bed"),
  `ThemeDB.fallback_font` size 8, white on dark fills / near-black on light fills
  (`label_color()`, by luminance). Slot dots (pale-yellow centre, dark rim) draw only
  when the static `ObjectView2D.show_slots` is true. `_process()` only updates
  `visible` (origin level vs `Session.viewed_level`) and re-queues a redraw when the
  flag flips — no per-frame repositioning.
- Debug flag choice: a static on `ObjectView2D`, synced from `game/main.gd._process()`
  (`ObjectView2D.show_slots = _debug_overlay.visible`). Main already owns both the
  overlay and a per-frame hook, so no `Session` or `DebugOverlay` change was needed
  and the ticket stays inside the named files.
- `game/main.gd`: `add_child(ObjectsView2D.new())` after `WorldView2D`, before
  `PeopleView2D` (objects under people), plus the one-line flag sync.
- Tests: `tests/game/test_objects_view_2d.gd` — 6 tests: label table incl. "Double
  bed" -> "Bed", label contrast, footprint rect, rebuild-twice yields no duplicates,
  added/removed events update views, visibility follows `viewed_level`.
- Screenshots (all opened and checked): `out/t0002.png --zoom=3` shows the player
  (yellow marker) on top of the flat with the "Fri" fridge block and "Tel" TV block
  labelled; the bed/sofa are outside that tight frame, so `out/t0002_wide.png
  --zoom=1` proves the full criterion — pale "Fri" fridge (kitchen, NE), black "Tel"
  TV, orange "Sof" sofa (living room, SW) and blue 2x2 "Bed" (bedroom, SE), all with
  dark outlines and centred labels, player drawn over the bedroom floor.
  `out/t0002_debug.png --zoom=3 --debug` shows the fridge slot dot; the wide debug
  shot shows all six dots (1 fridge, 1 TV, 2 sofa, 2 bed) as pale dots with dark rims.
- Quickload: `rebuild()` frees (`queue_free`) every old view and clears `_views`
  before re-adding from `Session.sim.world.objects`, and `Session._after_load()`
  drains stale sim events before emitting `game_loaded` exactly once — so a
  quickload (F8) rebuilds exactly one view per object. Covered by the
  rebuild-twice test (code inspection + reasoning, as the ticket allows).
- Verified: `tools/check.sh` → 125 passed, 0 failed (6 new tests included).

## Questions

## Review feedback
