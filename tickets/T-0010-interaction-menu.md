---
id: T-0010
title: Interaction menu (click / E) and action queue panel
status: draft
milestone: M1
size: M
owner: builder
depends_on: [T-0007, T-0009]
builder:
review_rounds: 0
---

## Goal
Clicking an object in command mode, or pressing E next to one in direct mode, opens a small menu of its interactions; choosing one queues it. A queue panel shows queued actions with cancel buttons.

## Notes for the architect (to detail before this becomes todo)
- Use `Interactions.offered_by()`; unavailable options greyed out with a reason (later).
- T-0002 as merged: `ObjectsView2D` holds one `ObjectView2D` per object; to find the
  object under the mouse, turn the click into a cell and use
  `Session.sim.world.objects_at(cell)`. `ObjectView2D.show_slots` draws use-slot dots.
- E picks the nearest object within 1.5 cells, preferring the facing direction.
- The menu is a PopupMenu or custom panel built in code; it must not leak input to movement while open.
- Queue panel: bottom-centre, max 6, cancel → CancelActionCommand.
- The panel's first row is the current action with a progress bar (moved here from T-0008):
  interaction name + minutes_done / duration, or the need value for until_need actions.
- Trend arrows on the needs panel fit here too, once actions can raise needs. T-0008 as
  merged: `NeedsPanel` (`game/ui/needs_panel.gd`) with `show_person(person, content)`,
  bars in `_bars`/`_fills` by need id, placed bottom-left by `Hud`.

## Implementation notes

## Questions

## Review feedback
