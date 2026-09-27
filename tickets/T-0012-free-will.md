---
id: T-0012
title: Free will: the idle player looks after their own needs
status: draft
milestone: M1
size: M
owner: builder
depends_on: [T-0011]
builder:
review_rounds: 0
---

## Goal
When the player's queue is empty and free will is on, the player picks interactions by utility (docs/design/actions-and-autonomy.md → Autonomy) using objects on the same place.

## Notes for the architect (to detail before this becomes todo)
- `sim/ai/utility.gd` (scoring, pure) + `sim/systems/autonomy_system.gd`; the rng stream "autonomy"; the free-will flag on Person (saved) + ToggleFreeWillCommand.
- Direct input suppresses autonomy for N minutes after the last input (the player is in control).
- Test: a 3-day headless run with free will keeps every need above 10 most of the time (define the metric exactly).

## Implementation notes

## Questions

## Review feedback
