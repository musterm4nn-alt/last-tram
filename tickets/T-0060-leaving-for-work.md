---
id: T-0060
title: Leaving for work on time - shifts as obligations
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0059]
builder:
review_rounds: 0
---

## Goal
People go to work by themselves. When it's time to leave (the shift start minus the walk),
residents drop what they're doing (an alarm wakes a sleeper) and head to their workplace. In
the morning you can watch the office workers gather at the tram stop and vanish. The player
gets a reminder an hour before their shift, and with free will on and nothing else to do,
goes by themselves too.

## Read first
`docs/design/actions-and-autonomy.md` → Routines and obligations;
`sim/systems/autonomy_system.gd`; T-0059 (the work action).

## Design (draft: detailed when its dependencies are merged)
- `WorkSystem` (`sim/systems/work_system.gd`), in `Sim.default_systems()` before
  `AutonomySystem` (obligations go before free will). Each minute, for every employed person
  whose shift today, or overnight from yesterday, hasn't started: leave at the shift start
  minus a travel estimate (Manhattan distance × 1.3 / walk speed, plus 2 minutes per floor
  change) minus 10 minutes.
- At leave time, NPCs (and the player, if free will is on and they have been idle for
  `AutonomySystem.IDLE_MINUTES`) cancel the current non-work action, sleep included (emitting
  `woke_for_work`), clear the path, and queue `work` at the front on the nearest workplace
  object with a free staff slot.
- `work_reminder {person_id, job_id, start_tick}`, emitted at exactly an hour before the shift
  (no saved state). The HUD shows "Your shift as office clerk starts at 09:00 (tram stop)".
- Nothing else changes for missed shifts yet (T-0061 counts them).

## Acceptance (sketch)
- A worker at home leaves in time and starts within 5 minutes of the shift start; a sleeping
  worker is woken; the player with free will off only gets the reminder; an idle player with
  free will on goes.
- Over a 3-day run almost nobody is late (simrun reports late and missed shifts), and
  `--check-m2` still passes.

## Implementation notes

## Questions

## Review feedback
