---
id: T-0091
title: Crimes on the record (M4's first step)
status: done
milestone: M4
size: M
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
M4's chain is crime → witness → report → police → consequences. This is its base: crimes
are content, an interaction can commit one, and every crime committed is kept (and saved) as
an incident that the next tickets react to. First crime: pocketing a snack at the Späti.

## Scope
`data/crimes.json`, `sim/content/crime_def.gd`, `crime_loader.gd`, `ContentDB.crimes` /
`crime(id)`, `InteractionDef.crime` (+ loader), `sim/crime/incident.gd`, `sim/crime/crimes.gd`,
`World.incidents` (save v20: `SaveMigrationsM4.v19_to_v20`, validator, fixture
`v20_basic.json`), the hook in `ActionSystem`, the filter in `Autonomy`, `steal_snack` in
`data/interactions/shops.json`. **Out of scope:** witnesses, police, any reaction, NPCs
committing crimes, UI beyond the object menu.

## Specification
- `CrimeDef`: `id`, `name`, `severity` (1–8). Nine crimes from the design doc.
- `InteractionDef.crime`: a crime id or "" (validated). When such an interaction finishes,
  `Crimes.commit(sim, person, crime_id, target_id)` records an `Incident` (id from
  `World.new_id()`, crime, perpetrator, target, cell, lot, tick) and emits
  `crime_committed {incident_id, crime_id, person_id}`.
- Free will never picks an interaction with a crime (until NPC crime, later in M4).
- `steal_snack` ("Pocket a snack") at the Späti counter: 2 minutes, free, +15 hunger,
  commits shoplifting.

## Acceptance criteria
- [x] Crimes load and interactions name them → `test_crimes.gd: test_crime_content_loads`
- [x] Pocketing a snack costs nothing, feeds you and records the incident and event →
  `test_stealing_a_snack_is_free_and_recorded`
- [x] Incidents survive save/load; v19 saves load with none; bad incidents are rejected →
  `test_incidents_survive_save_and_load`, `test_old_saves_load_with_no_incidents`,
  `test_bad_incidents_are_rejected`
- [x] A day of the town with free will commits no crime → `test_free_will_never_steals`

## Implementation notes
Built by the architect. Nothing reacts to crimes yet, so pocketing a snack is (for now)
consequence-free; the next tickets add witnesses and the police. `tools/check.sh` passes.
