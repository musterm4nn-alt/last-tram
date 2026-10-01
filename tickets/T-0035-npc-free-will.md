---
id: T-0035
title: Neighbours live by free will
status: done
milestone: M2
size: S
owner: builder
depends_on: [T-0034]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Every resident uses the same free will as the player to eat, sleep, wash and relax at home,
with no NPC-specific code paths. Nobody ever shares a slot, and the simulation report shows
how the residents are doing.

## Scope
`data/world/districts/altstadt/objects.json` (a desk with laptop and a TV in every
neighbour flat), `tools/sim_runner.gd` (resident summary), `tests/sim/test_neighbours_live.gd`,
`tests/sim/test_upper_floors.gd` (the furniture list).
**Out of scope:** going out and daily rhythm (T-0036), talking to each other (T-0038/39).

## Acceptance criteria
- [x] Over a day, every person sleeps and eats, no two people hold the same slot in any
  minute, and fewer than 2% of need samples are below 30 → `test_neighbours_live.gd`.
- [x] Residents only choose objects on lots they may enter → `test_neighbours_live.gd`.
- [x] Every neighbour flat has a desk and a TV with reachable slots → `test_upper_floors.gd`.
- [x] `tools/simrun.sh` prints a residents summary; `tools/check.sh` passes.

## Implementation notes
- No code changes were needed in the sim: AutonomySystem already treats everyone alike, and
  T-0034 made it cheap enough (D27).
- First 3-day run: residents' Fun was below 30 in 85% and Social in 80% of person-minutes,
  because the T-0031 flats had nothing for either. With a desk (laptop: browse the web,
  video calls) and a TV in each of the 15 flats, `tools/simrun.sh --days=3` shows 0.0% of
  resident minutes below 30 for every need (lowest: hunger 37.5). Residents finished 608
  sits, 412 TV sessions, 227 meals, 188 calls, 186 showers and 160 sleeps.
- Cost: 0.059 ms per step with 26 people.
- Verified: `tools/check.sh` passes.

## Questions

## Review feedback
