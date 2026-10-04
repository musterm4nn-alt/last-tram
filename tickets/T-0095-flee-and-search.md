---
id: T-0095
title: Getting away from the police
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0094]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The player can escape: an officer who loses sight of their suspect searches the area around
where they last saw them, and gives up after a while. Getting away cools the wanted level
off in hours instead of days, unless an officer spots you again.

## Docs
[docs/design/crime-and-police.md](../docs/design/crime-and-police.md) "Police" (chase,
search, give up; heat decays while you stay out of sight) · D36

## Scope
- `PoliceTask.search_until` (saved; -1 = not searching), `Incident.lost_tick` (saved; -1 =
  not lost, read as -1 when absent).
- `sim/crime/police_search.gd` (new `PoliceSearch`): start, step and give up.
- `Police.chase` uses it; `Police.sought_people` replaces `wanted_people` for dispatch; a
  returning officer who sees a suspect who is still wanted chases them again.
- `MovementSystem.speed`: an officer on a call runs at most `officer_run_speed`.
- `"police"` in `data/crimes.json`: `officer_run_speed`, `search_minutes`, `search_radius`, `lost_heat_hours`
  (+ `PoliceRules`, `CrimeLoader` with validation).
- Save validator, HUD notices, tests, the design doc.

**Out of scope:** jail (it comes with burglary, the first crime serious enough), stamina,
night and weekend police shifts, NPC suspects fleeing on purpose.

## Specification
- An officer chasing (not returning) who can't see the suspect and has no path left (they
  reached `last_seen`, or there is no way there) starts searching: `search_until = now +
  search_minutes`, `running` off, emits `police_searching {officer_id, person_id}`.
- While searching, whenever the officer's path is empty they walk to a random walkable cell
  on the same floor within `search_radius` (Chebyshev) of `last_seen` that they can reach
  (up to 8 draws from the "police" stream; stay put if none).
- Seeing the suspect again ends the search (`search_until = -1`, running on, chase as before).
- At `search_until` they give up (`PoliceSearch.give_up`): each of the suspect's counting
  incidents gets `lost_tick = now`, the officer walks back (`Police.go_back`), and
  `police_gave_up {officer_id, person_id}` is emitted.
- A lost incident still counts towards the wanted level, but only for `lost_heat_hours` after
  `lost_tick` (and never longer than `heat_hours` after the report).
- `Police.sought_people(sim)`: the people (ascending) with a counting incident that is not
  lost. Only they get officers dispatched; a new report makes you sought again.
- A returning officer who sees a suspect who is still wanted turns round: `lost_tick` back to
  -1 on that suspect's incidents, `returning` off, running on, `police_spotted
  {officer_id, person_id}`.
- HUD notices: "The police lost sight of you", "The police gave up looking for you",
  "The police spotted you again".

## Acceptance criteria
- [x] Out of sight, the officer goes to where they last saw the suspect and searches near
  there, walking → `test_police_search.gd: test_out_of_sight_the_officer_searches`
- [x] Seeing the suspect again during the search resumes the chase →
  `test_seeing_the_suspect_again_resumes_the_chase`
- [x] After `search_minutes` the officer gives up and walks back; the incidents are lost; no
  new officer is sent → `test_the_officer_gives_up_and_nobody_else_comes`
- [x] A lost suspect's wanted level cools off after `lost_heat_hours` →
  `test_getting_away_cools_off_sooner`
- [x] A new report sends an officer again → `test_a_new_crime_brings_the_police_back`
- [x] A returning officer who spots the suspect turns round →
  `test_a_returning_officer_turns_round`
- [x] Officers on a call run at most `officer_run_speed` (8, a running player does 9), so the
  player can outrun one with direct control → `test_running_away_gets_away`
- [x] Searches survive save and load, and bad values are rejected →
  `test_a_search_survives_save_and_load`, `test_bad_search_values_are_rejected`
- [x] Content numbers load and are validated → `test_crimes.gd`
- [x] HUD notices → `test_hud_place.gd: test_police_notices`

## Implementation notes
Built and reviewed by the architect (D36 extended). `tools/check.sh` passes (765 tests).

- `sim/crime/police_search.gd` (`PoliceSearch.step/found/give_up/spotted`); `Police.chase`
  calls it; `Police.counts` (public now) applies `lost_heat_hours`; `Police.sought_people`
  replaced `wanted_people` (only PoliceSystem used it); `Police.head_to` is public for
  PoliceSearch.
- Officers ran as fast as a running player (both 9 cells a minute), so a chase could never be
  won or lost by running: the gap stayed the same. `officer_run_speed` 8 (in
  `MovementSystem.speed`) lets a runner gain a cell a minute; `test_running_away_gets_away`
  fails without it.
- The search walks to random reachable cells near `last_seen` (stream "police").
- Jail moved out of this ticket: no crime in the game is serious enough yet (it comes with
  burglary).
- No screenshot: nothing new is drawn except the three notices (tested as text).

## Review feedback

## Questions
