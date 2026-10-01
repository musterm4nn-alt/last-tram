---
id: T-0036
title: Daily routines - sleep at night, and go home
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0035]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
People keep a rhythm. Each person has a routine (early bird, regular, night owl) with a sleep
window. Inside it, sleep is very attractive and a sleeper stays in bed until the window ends;
outside it, sleep is unattractive unless they are exhausted. Someone idle away from home with
nothing to do, or out during their sleep window, walks home. This fixes the M1 "naps at noon"
issue and T-0032's "stranded at the Späti" for the player too. Going out in the evening is
T-0052.

## Read first
- `docs/design/actions-and-autonomy.md` → "Routines and obligations (M2)"
- As merged: `sim/ai/autonomy.gd`, `sim/systems/autonomy_system.gd`,
  `sim/systems/action_system.gd` (`_has_ended`), `sim/people/resident_generator.gd`,
  `sim/content/needs_loader.gd` (loader pattern)

## Scope
Create `data/routines.json`, `sim/content/routine_def.gd`, `sim/content/routine_loader.gd`,
`sim/ai/routines.gd`, `tests/sim/test_routines.gd`. Change `sim/content/content_db.gd`,
`sim/content/interaction_def.gd` and `interaction_loader.gd` (`routine` field),
`data/interactions/basics.json` (sleep), `sim/people/person.gd` (`routine_id`),
`sim/people/resident_generator.gd`, `sim/sim_factory.gd`, `sim/ai/autonomy.gd`,
`sim/systems/autonomy_system.gd`, `sim/systems/action_system.gd`,
`sim/save/save_person_validator.gd`, `tools/sim_runner.gd` (asleep count in reports).
**Out of scope:** going out (T-0052), work shifts (M3), choosing a routine in the creator.

## Specification
- `data/routines.json`: `{"default": "regular", "routines": [{id, name, sleep_hours: [start,
  end], weight}]}`: early_bird 22–6 (30), regular 23–7 (45), night_owl 2–10 (25). Hours
  wrap past midnight like lot hours. Validated (ids, hours 0..24, weight > 0, the default
  exists). `ContentDB.routines`, `routine(id)`, `default_routine`.
- Interactions gain optional `"routine": "sleep"` (validated: "sleep" or "out"). Sleep has it.
- `Person.routine_id` (saved; "" = the default). New-game player: the default. Residents:
  weighted by `weight`, drawn after each member's spec.
- `Routines` (static, `sim/ai/routines.gd`): `routine_of(sim, person)`,
  `static in_hours(hours: Vector2i, hour: int) -> bool`, `sleeping_time(sim, person)`,
  `score_factor(sim, person, def)` (routine "sleep": `SLEEP_IN_WINDOW` 2.0 inside the
  window, `SLEEP_OUTSIDE` 0.3 outside; else 1), `keeps_sleeping(sim, person, def)`,
  `home_route(sim, person) -> Array[Vector3i]` (a path to the first free walkable cell of the
  home place, scan order; [] when at home or no home).
- `Autonomy.candidates`: score = need_score × `Routines.score_factor` − travel.
- `ActionSystem`: an `until_need` action with routine "sleep" doesn't end at a full need while
  `keeps_sleeping` (max_minutes still ends it).
- `AutonomySystem`: before choosing, someone in their sleep window who is not on their home
  lot heads home. When choosing finds nothing and they are not home, they head home instead of
  waiting. Heading home sets `person.path` and emits `&"heading_home"` {person_id}.
- `tools/sim_runner.gd` reports how many people are asleep at each report line.

## Acceptance criteria (`tests/sim/test_routines.gd`)
- [x] Routines load; bad hours, an unknown default and an unknown interaction routine are
  reported.
- [x] The player is "regular"; over 10 seeds, residents get all three routines.
- [x] Sleep scores ×2 inside the window and ×0.3 outside it.
- [x] Asleep inside the window with full energy: still sleeping; the window ends: they wake.
  Outside the window, sleep ends at full energy.
- [x] Someone idle on the Altmarkt with nothing in reach walks home and arrives; someone
  away from home in their sleep window heads home before anything else.
- [x] Over 2 days, at 03:00 at least 80% of people are asleep at home, and at 15:00 at most
  10% are asleep.
- [x] `routine_id` survives save/load. `tools/check.sh` passes; `tools/simrun.sh --days=3`
  keeps everyone's needs healthy.

## Implementation notes
- As specified. `Lots.free_cells` (moved from ResidentGenerator) is shared by the generator
  and `Routines.home_route`. Each resident's routine is drawn after their spec, so seed 1 now
  has 30 residents (the draws shifted).
- Found by the M1 acceptance test: an 8-hour night let Fun fall to 0 (sleep used to end at
  full energy after 2–3 hours). Sleep now also has hunger +3, hygiene +2, fun +5 and
  social +3 per hour, so those fade more slowly overnight (net −3, −2, −1, −1 per hour).
  `test_sleep_skip.gd`'s critical-hunger setup starts at 15.02 instead of 15.05 so the same
  first-minute crossing still happens.
- Verified: `tools/check.sh` 409 passed, 0 failed (`test_routines.gd`, 9 tests).
  `tools/simrun.sh --days=3`: no need below 30 for anyone; asleep counts show the rhythm
  (Mon 14:00 0 of 31, Tue 05:00 26 of 31, Tue 14:00 0). 0.069 ms per step.

## Questions

## Review feedback
