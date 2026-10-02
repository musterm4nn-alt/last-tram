---
id: T-0060
title: Leaving for work on time - shifts as obligations
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0059]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
People go to work by themselves. When it's time to leave (the shift start minus the walk),
residents drop what they're doing (an alarm wakes a sleeper) and head to their workplace. In
the morning you can watch the office workers gather at the tram stop and vanish. The player
gets a reminder an hour before their shift, and with free will on and no input for a while,
goes by themselves too.

## Read first
`docs/design/actions-and-autonomy.md` → Routines and obligations;
`sim/systems/autonomy_system.gd` (idle rule, `_head_home`), T-0059 (`Jobs`, the work action),
`game/ui/hud.gd` (`notice_for_event`).

## Scope
Create `sim/systems/work_system.gd`, `tests/sim/test_leaving_for_work.gd`.
Change `sim/sim.gd` (`default_systems`), `sim/jobs/jobs.gd`, `game/ui/hud.gd`,
`tools/sim_runner.gd`, tests that relied on residents never leaving.
**Out of scope:** missed shifts and their consequences (T-0061), pay (T-0061).

## Specification
- `WorkSystem` (no state), in `Sim.default_systems()` right before `AutonomySystem`
  (obligations go before free will). `on_minute`, for every person with a job:
  - The **next shift**: `Jobs.next_shift(sim, person) -> Vector2i`, the earliest of
    yesterday's, today's and tomorrow's shift windows (`shift_on`) that hasn't ended.
  - **Leave time** = start − `Jobs.travel_minutes(sim, person)` − `LEAVE_MARGIN` (10)
    minutes. `travel_minutes` = ceil(Manhattan distance from the person's cell to the nearest
    workplace object × 1.3 / walk speed) + 2 per floor between them.
  - From leave time until the shift ends, if the person isn't working and has no work action
    queued, at leave time and then every `RETRY_MINUTES` (15) minutes after it:
    - NPCs, and the player when `free_will` is on and they have had no input for
      `AutonomySystem.IDLE_MINUTES`, **go**: the current front action is cancelled with reason
      `"work"` (a sleeper emits `woke_for_work {person_id}` first), any path is cleared, and a
      `work` action on the workplace object nearest by Manhattan distance with a free staff
      slot is put at the front of the queue. Emit `left_for_work {person_id, job_id}`.
    - Otherwise (the player with free will off, or busy): nothing.
  - **Reminder:** for the player only, at exactly an hour before the start, emit
    `work_reminder {person_id, job_id, start_tick}`. `Hud.notice_for_event` words it as
    "Work at 09:00: Office clerk (Tram shelter)".
- `Jobs.workplace(sim, person) -> WorldObject`: the nearest workplace object (tag and place)
  with a free staff slot, or null.
- simrun: `work: shifts started N (late M, average lateness X min), left early K`.

## Acceptance criteria (`tests/sim/test_leaving_for_work.gd`)
- [x] A police officer at home on Tuesday 05:00 leaves in time and starts the 06:00 shift
  within 5 minutes of 06:00.
- [x] A warehouse worker asleep at 05:00 is woken (`woke_for_work`) and gets there.
- [x] The player with free will off gets the reminder at 08:00 and isn't sent to work; with
  free will on and idle, they go; with recent input, they're left alone.
- [x] Over 3 days of the whole town, almost nobody is late: average lateness under 10
  minutes, and every weekday office shift is started (simrun numbers in the notes).
- [x] `tools/check.sh` passes; `--check-m2` passes on seeds 1–3 (people still eat, sleep at
  home and socialise with work in their days). Existing tests that assumed nobody leaves are
  adjusted (listed in the notes).

## Implementation notes
- `WorkSystem` as specified (leave time from a cheap travel estimate, worked out only within
  3 hours of a shift; retries every 5 minutes; a nearly finished action may finish first;
  reminders for the player). The HUD words the reminder "Work at 09:00: Office clerk (Tram
  shelter)". simrun prints a `work:` line.
- **Most of the work was keeping working people healthy** (D30): jobs' need rates, days off
  for shop staff, the hour-awake rule and the `early_shift` routine, showers of 85, hygiene
  weighing 1.2, home needs first (`Routines.home_needs`, `AutonomySystem._see_to_home_needs`:
  wash, eat at home, eat out or shop when the fridge is empty, other needs under 30), and
  colleagues (`Jobs._know_colleagues`). `TownCheck` counts a finished shift as a meal and a
  social contact; `test_neighbours_live.gd` counts lunch at work as eating.
- Tests adjusted, not loosened: `test_free_will.gd`, `test_m1_day_at_home.gd` and one
  `test_routines.gd` test make the player jobless (they test home life); the shower test uses
  the new +85 (starting at 10 so it doesn't hit 100); `test_out_in_the_sleep_window_heads_home_first`
  accepts heading home to cook; `test_jobs.gd` checks the new day patterns.
- Verified: `tools/check.sh` 533 passed, 0 failed (`test_leaving_for_work.gd`, 6 tests).
  `tools/simrun.sh --days=7 --check-m2` PASSED on seeds 1–6 at 0.11–0.14 ms per step
  (budget 0.25). Shifts started about 80 a week per town; average lateness about 8 minutes
  (mostly Monday morning, when the game starts at 08:00).

## Questions

## Review feedback
