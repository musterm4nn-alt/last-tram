---
id: T-0092
title: Witnesses
status: done
milestone: M4
size: M
owner: builder
depends_on: [T-0091]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The second link of M4's chain: when a crime happens, the people who can see it notice it,
remember it, and are listed on the incident (the police and gossip build on that).

## Scope
`sim/crime/witnesses.gd`, `sim/content/witness_rules.gd`, `"witness"` in `data/crimes.json`
(+ `CrimeLoader`, `ContentDB.witness_rules`), `Incident.witnesses` (saved; older v20 saves
read as none, so no version bump), the call in `Crimes.commit`, the validator, tests.
**Out of scope:** reactions (flee, intervene, report), identification by clothes and light,
background-tier rolls.

## Specification
- `Witnesses.find(sim, cell, except_id) -> PackedInt32Array`: people on the same floor
  within `sight_range` (day 8 cells, night 5 from 21:00 to 06:00; Chebyshev distance),
  not asleep (`routine == "sleep"`), not hidden in a rabbit hole (`Jobs.hidden`), with a clear
  line (Bresenham over cells; the end cells don't count; terrain or objects with
  `blocks_sight` block: walls, doors, hedges). Ascending ids.
- `Witnesses.record(sim, incident)`: sets `incident.witnesses`; each witness remembers
  `"saw_crime"` about the perpetrator (valence -40, salience 70) and `crime_witnessed
  {incident_id, person_id}` is emitted.

## Acceptance criteria
- [x] Range, walls, night, sleepers and floors → `test_witnesses.gd: test_who_sees_by_day`,
  `test_the_night_shortens_sight`, `test_sleepers_and_other_floors_see_nothing`
- [x] Witnesses get the memory and are saved on the incident →
  `test_a_crime_gives_witnesses_a_memory_and_lists_them`
- [x] The Späti clerk on shift sees a pocketed snack → `test_the_spaeti_clerk_sees_a_snack_pocketed`

## Implementation notes
Built by the architect. Witnessing has no visible effect yet beyond the memory (the person
inspector lists memories); reports and the police come next. `tools/check.sh` passes.
