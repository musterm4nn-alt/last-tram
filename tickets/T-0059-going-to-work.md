---
id: T-0059
title: Going to work - the work action and the rabbit hole
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0058, T-0056]
builder:
review_rounds: 0
---

## Goal
Working becomes something you do. During your shift you can choose "Work" at your workplace:
for a city job that's the tram stop on the Altmarkt (you take the tram and disappear until the
shift ends); for the police it's the desk in the Polizeiposten. The game skips ahead while you
work, like sleep, and your needs change the way the job says. This is the first `WorkSession`
(the rabbit hole). Going on your own comes next (T-0060), and pay comes in T-0061.

## Read first
D10, D29 (work is an action); `docs/design/jobs-and-economy.md` → Jobs and careers;
`sim/systems/action_system.gd`, `sim/content/use_slot_def.gd`, `sim/ai/autonomy.gd`
(`_cells_to_free_slot`), `game/view2d/people_view_2d.gd`, `sim/social/conversations.gd`
(`available`).

## Design (draft: detailed when its dependencies are merged)
- **Slot roles:** `UseSlotDef.role` ("customer", the default, or "staff"). Work uses only
  staff slots; everything else only customer slots (`ActionSystem._choose_route`,
  `Interactions.slot_at_person`, `Autonomy._cells_to_free_slot`). Counters gain staff slots
  behind them (Späti, Imbiss, bar).
- **Workplace objects:** `tram_stop` (a shelter at `tram_stop_altmarkt`, 8 staff slots) and
  `police_desk` (inside the Polizeiposten, 2 staff slots).
- **The work interaction** (`data/interactions/work.json`): `work` ("Work"), `"work": true`,
  `"time_skip": true`, and no duration (it lasts until the shift ends; the loader allows that
  only for work).
- **Requirements:** `not_your_job` (hidden from the menu) unless the object has the job's
  `workplace_tag` and stands on the job's place; `not_your_shift` unless it is between an
  hour before the shift and its end.
- **`WorkSession`** (`sim/jobs/work_session.gd`): `begin`, `on_minute`, `finish -> WorkResult`
  (`minutes`, `late_minutes`, `left_early`); `RabbitHoleWork` applies the job's `need_rates`
  and is hidden. `WorkSessions.for_job(job)` maps the session type to an implementation, with
  the rabbit hole standing in for on-site until T-0065.
- **ActionSystem:** for a work action, `begin` when it starts, `on_minute` instead of
  `need_rates`, it ends at the shift end, and `finish` runs on finishing, cancelling or
  failing (leaving early). `Jobs.record_shift(sim, person, result)` keeps the minutes worked
  this week on `Employment` (pay comes in T-0061).
- **Hidden people:** `Jobs.hidden(sim, person)`. The people view skips them, conversations
  and social free will treat them as unavailable, bubbles skip them, and the inspector says
  "At work until 17:00".

## Acceptance (sketch)
- The player can choose Work at the tram stop during their shift and not otherwise. They
  disappear, the game skips, and they reappear at the stop at 17:00 with needs changed by the
  job. Walking away ends the shift early.
- Staff slots and customer slots don't mix. A save mid-shift continues identically.
  Screenshot: the menu at the tram stop.

## Implementation notes

## Questions

## Review feedback
