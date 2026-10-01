---
id: T-0052
title: Going out - the Kneipe, the café and the benches in the evening
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0036]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The second half of the old T-0036 draft. Public places get things to do: a bar counter and
tables at the Kneipe (have a drink), café tables at Café Wolke (have a coffee), and benches on
the Altmarkt (sit outside). Each routine has an evening "out" window. Inside it, free will also
considers these places anywhere in town, and the further away, the less likely. Sociable
people go out more. Opening hours apply (T-0032), and people head home afterwards (T-0036).

## Scope
Create `data/objects/public.json`, `data/interactions/going_out.json`,
`tests/sim/test_going_out.gd`. Change `data/routines.json` (`out_hours`),
`sim/content/routine_def.gd`, `routine_loader.gd`, `sim/ai/routines.gd`, `sim/ai/autonomy.gd`,
`data/world/districts/altstadt/objects.json` (placements), docs.
**Out of scope:** talking to people there (T-0038/39), money for drinks (M3).

## Specification
- Objects: `bar_counter` (4×1, four slots below), `pub_table` (2×1, two slots above and two
  below), `cafe_table` (1×1, slots left and right), `bench` (2×1, two slots below; tags
  `bench`, `seat`). Placed: Kneipe, counter (47,7) and tables (48,11), (51,9); café tables
  (23,8), (27,8), (23,11), (27,10); Altmarkt benches (25,26), (37,26), (28,32), (34,32).
- Interactions (routine "out"): `have_a_drink` (bar; 45 min; fun 20, social 12, comfort 10 per
  hour), `have_a_coffee` (cafe_table; 30 min; fun 10, social 8, energy 8, comfort 10),
  `sit_outside` (bench; 30 min; fun 8, comfort 20, social 4).
- `RoutineDef.out_hours`: early bird 17–21, regular 19–23, night owl 21–2.
- `Routines.going_out_time(sim, person)`. `Routines.score_bonus(sim, person, def)`: for routine
  "out" inside the out window, `OUT_BONUS` (5) × (1 + 0.5 × sociability / 100); else 0.
  `score_factor` for "out" outside the window is 0.5.
- `Autonomy.candidates`: inside the out window, objects offering an "out" interaction count
  on any level and at any distance (walking cost still applies; a far object's distance is
  its first reachable free slot). Score = need × factor + bonus − travel.

## Acceptance criteria (`tests/sim/test_going_out.gd`)
- [x] The new objects and interactions load, and every placement has a usable slot.
- [x] Out bonus: inside the window it is positive and larger for sociable people; outside it
  is 0.
- [x] In the out window, an idle person at home gets a Kneipe option; outside it they don't.
- [x] A closed place (café after 19:00) offers nothing.
- [x] Over 2 days, someone has a drink at the Kneipe, a coffee at the café and sits on a bench;
  at 03:00 most people are still asleep at home, and needs stay healthy.
- [x] `tools/check.sh` passes; screenshot `out/t0052.png` of the Kneipe in the evening.

## Implementation notes
- As specified, plus two tuning changes found by looking at the town:
  - `Routines.SLEEP_BONUS` (+6 for sleep in the sleep window). Daytime naps left people not
    tired enough at bedtime, so the TV won.
  - `have_a_drink` also has hunger +8/h (bar snacks). Nights out were costing meals: the lowest
    resident hunger in 3 days went from 10.8 to 15.8, and below 30 from 1.6% to 0.7% of minutes.
- `test_routines.gd` (T-0036) measures the night at 05:00 instead of 03:00 (75% asleep at home):
  night owls now go out until 2 and walk home after the Kneipe closes. Its loader test's sample
  routine gained the now-required `out_hours`.
- Verified: `tools/check.sh` 414 passed, 0 failed (`test_going_out.gd`, 5 tests).
  `tools/simrun.sh --days=3`: resident actions include 273 drinks, 241 bench sits and 14
  coffees (the café closes at 19:00); asleep counts still follow the routines. Screenshot
  `out/t0052.png` (Mon 20:57): the Kneipe is full, two benches are taken, and the café is
  closed and empty.

## Questions

## Review feedback
