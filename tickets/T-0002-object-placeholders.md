---
id: T-0002
title: Draw world objects as placeholders
status: todo
milestone: M1
size: S
owner: builder
depends_on: [T-0001]
builder:
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
  (`data.object_id`).
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

## Questions

## Review feedback
