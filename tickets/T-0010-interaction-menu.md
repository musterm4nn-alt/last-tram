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
- E picks the nearest object within 1.5 cells, preferring the facing direction.
- The menu is a PopupMenu or custom panel built in code; it must not leak input to movement while open.
- Queue panel: bottom-centre, max 6, cancel → CancelActionCommand.

## Implementation notes

## Questions

## Review feedback
