---
id: T-0094
title: Police response and arrest
status: done
milestone: M4
size: L
owner: builder
depends_on: [T-0093]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The fourth link of M4's chain: once someone is wanted, an on-duty police officer leaves the
Polizeiposten, runs to where the crime was reported, follows the suspect while they can see
them, and arrests them when they catch up: a fine, the case closed, and a criminal record.

## Docs
[docs/design/crime-and-police.md](../docs/design/crime-and-police.md) "Police" ·
[docs/architecture.md](../docs/architecture.md) "Systems"

## Scope
- `sim/crime/police_task.gd` (new `PoliceTask`), `World.police_tasks` (saved),
  `Incident.closed_tick` (saved; -1 = open, read as open when absent).
- `sim/crime/police.gd`: `wanted_level` ignores closed incidents; `on_call`, `on_duty`,
  `dispatch`, `chase`, `arrest`, `fine_for`.
- `sim/systems/police_system.gd` (new), added to `Sim.default_systems()` after `WorkSystem`.
- `ActionSystem`: an officer on a call keeps performing their work action away from the desk.
- `Jobs.hidden`: false for an officer on a call (they are out in the street).
- `Money.fine` and the sink `"fine"` (cash first, then the bank, which may go below zero);
  `BankApp.REASONS["fine"]`.
- `"police"` in `data/crimes.json`: `fine_per_severity`, `arrest_range` (+ `PoliceRules`,
  `CrimeLoader`).
- `SaveValidator`, `test_determinism.gd` `SAVED_CLASSES`, HUD notices.
- Docs: architecture "Systems", decisions D36, the design doc.

**Out of scope:** fleeing and giving up the search (T-0095), jail, night shifts for the
police, uniforms (art), NPC crime (T-0097), resisting arrest.

## Specification
- `PoliceTask` (RefCounted): `officer_id: int`, `target_id: int`, `last_seen: Vector3i`
  (where the officer is heading: the reported crime's cell, then wherever they last saw the
  suspect), `returning: bool` (walking back to the desk after an arrest). `to_dict` /
  `from_dict`. `World.police_tasks: Dictionary[int, PoliceTask]` by officer id, saved as a
  list sorted by officer id (`"police_tasks"`, absent = none); tasks whose officer or target
  no longer exists are dropped on load.
- `Police.on_duty(sim, person)`: has the job `Police.JOB_ID` (`"police_officer"`) and
  `Jobs.working`. `Police.on_call(sim, person)`: has a task.
- `PoliceSystem.on_minute`: (1) ends tasks whose officer is no longer working (path cleared,
  running off) and, for tasks not returning, whose target's wanted level is 0 (the officer
  returns); (2) for each person (ascending id) with wanted level 1+ and no officer on them,
  dispatches the nearest free on-duty officer (Manhattan + 10 per floor, ties lower id) to the
  cell of their latest open reported incident: a task, `running` on, a path; emits
  `police_dispatched {officer_id, person_id}` (person_id = the suspect).
- `PoliceSystem.step` → `Police.chase` for each task (ascending officer id): an officer who
  can see the suspect (same floor, within `Witnesses.sight_range`, `Witnesses.clear_line`,
  suspect not hidden) updates `last_seen` and re-paths when it moved; within `arrest_range`
  (feet distance, same floor) of a visible suspect → `Police.arrest`. A returning officer who
  reached the desk slot ends the task.
- `Police.arrest(sim, officer, suspect)`: fine = Σ severity × `fine_per_severity` over the
  suspect's open reported incidents, paid with `Money.fine` (detail: the first crime id);
  those incidents get `closed_tick`; `suspect.record = true`; the suspect's front action is
  cancelled ("arrested"), path and move intent cleared, running off (an NPC's queue is
  cleared); the officer stops running and walks back to the desk (`returning`); emits
  `arrested {person_id, officer_id, fine, incidents}`.
- HUD notices for the player: "The police are looking for you" and
  "Arrested: fined €100.00. It's on your record now."

## Acceptance criteria
- [x] Closed incidents don't count towards the wanted level →
  `test_police_response.gd: test_closed_incidents_dont_count`
- [x] A reported crime sends the nearest on-duty officer, not an off-duty one →
  `test_the_nearest_on_duty_officer_is_dispatched`, `test_nobody_comes_without_an_officer_on_duty`
- [x] The officer leaves the desk visibly, keeps working the shift, and the work action is not
  cancelled → `test_an_officer_on_a_call_keeps_the_shift`
- [x] The officer catches the player, who is fined (cash then bank, below zero if need be),
  gets a record, and the incidents close; the officer walks back to the desk →
  `test_the_officer_catches_and_fines_the_player`, `test_a_fine_can_overdraw_the_bank`
- [x] The whole chain from a stolen snack, end to end in the real town, and the same after a
  save and load mid-chase → `test_shoplifting_end_to_end`, `test_a_chase_survives_save_and_load`
- [x] The task ends with the shift → `test_the_call_ends_with_the_shift`
- [x] Content: `fine_per_severity`, `arrest_range` load and are validated →
  `test_crimes.gd: test_crime_content_loads`
- [x] HUD notices → `test_hud_place.gd: test_police_notices`
- [x] Screenshot `out/t0094.png`: an officer running at the player after a reported theft

## Implementation notes
Built and reviewed by the architect (D36). `tools/check.sh` passes (755 tests);
`tools/simrun.sh --days=7 --check-m2` passes (seed 1).

- `sim/crime/police.gd` holds the logic (`dispatch`, `can_see`, `chase`, `arrest`, `go_back`,
  `end_call`, `desk_cell`, `fine_for`, `wanted_people`, `last_reported_cell`);
  `sim/systems/police_system.gd` only calls it, in ascending officer id. A returning
  officer counts as free, so a second call can take them straight from the street.
- `ActionSystem` (two lines) lets an officer on a call keep performing the work action away
  from the desk; `Jobs.hidden` is false for them. `Money.fine` is a new sink, `"fine"`.
- Save: `Incident.closed_tick` and `World.police_tasks` are read with defaults, so no new
  save version (as T-0093 did); the validator checks both; `Incident` and `PoliceTask` joined
  the save-field coverage test.
- In the real town (seed 1, the player steals four snacks from 8:00) the clerk reports the
  fourth at 8:21, the morning officer leaves the Polizeiposten at 8:22, runs across the
  Altmarkt and arrests the player at 8:28 by the tram stop: fined €100 (€40 cash, €60 from
  the bank). Screenshots: `out/t0094.png` (the officer running in from the right, "The police
  are looking for you", Wanted ★), `out/t0094_arrest.png` (the officer next to the player,
  "Arrested: fined €100.00. It's on your record now.", no stars).
- Officers look like anyone else (no uniform yet: art). Only the weekday 6-22 shifts exist,
  so nights and weekends have no police: T-0095 or later should decide whether that stays.
- Seen in passing (not changed): someone switched from the background tier to active at a
  minute boundary loses that minute's walk (`TierSystem` runs first in the minute, then
  `MovementSystem.on_minute` skips them as active).

## Review feedback

## Questions
