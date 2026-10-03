---
id: T-0076
title: M3 acceptance - 30 days of a working town
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0065, T-0066, T-0070, T-0073, T-0074, T-0075, T-0078, T-0079]
builder: Claude Code / Opus
review_rounds: 1
---

## Goal
Prove M3 is done: a 30-day headless run in which the economy stays stable (no mass
bankruptcy or evictions, the ledger balances, shops are staffed), and a test in which the
player gets hired, gets paid, pays rent and gets fired. Plus the owner's playtest checklist.

## Read first
The roadmap's M3 "Done when"; `tools/town_check.gd` and T-0045 (the M2 acceptance pattern).

## Design
- `tools/economy_check.gd`: `class_name EconomyCheck extends RefCounted`, used like
  `TownCheck`. `start(sim)` records the employment rate; `observe(sim, event)` counts
  `&"evicted"`; `end_of_day(sim)` (called at each midnight) checks the day: the ledger balances
  (`Money.held(world) == ledger.balance()`), at most `MAX_BROKE_SHARE` (10%) of people hold
  under `BROKE_CENTS` (€5) in all, and the employment rate (working-age residents, not the
  player, with a job) stays within `MAX_EMPLOYMENT_SWING` (20 points) of the start.
  `failures(sim, town)` adds more than `MAX_EVICTIONS` (1) evictions and any staffed place
  served under `MIN_STAFFED_SHARE` (80%) of its open time (from `TownCheck.staffed_share`).
  `summary()`, `broke_people(sim)`, `employment_rate(sim)`.
- `tools/sim_runner.gd --check-m3` (run with `--days=30`): fails on `EconomyCheck.failures`,
  any `TownCheck.failures` (the M2 rules over the whole run) or a cost over
  `BUDGET_MS_PER_STEP`. Every run prints the `economy:` summary line.
- `tests/sim/test_economy_check.gd`: a day of the town passes; the check notices money from
  nowhere, mass bankruptcy, collapsing employment, two evictions and an unstaffed shop.
- `tests/sim/test_m3_making_a_living.gd`: a Student (no job) applies until hired, works every
  shift to Friday with a save and load after the first, is paid on Friday at 18:00, pays rent
  and bills on Monday at 08:00, then misses shifts until warned and fired.

## Acceptance
1. `tools/simrun.sh --days=30 --check-m3` passes on seeds 1, 2 and 3. (Run by hand: about
   2.5 minutes each here; not in the suite.)
2. The player-flow test passes (`test_m3_making_a_living.gd`).
3. The check can fail: `test_economy_check.gd`.
4. The roadmap shows M3 waiting for the owner's playtest.

## The owner's playtest (an evening and a week)
Start a new game as a **Student** (no job, about €100).
1. Open the phone (P) → Jobs. Apply for something; get washed and dressed first (it helps).
   Next day: go to work on time (the Jobs app says when and where).
2. Work Monday to Friday. On Friday at 18:00 the wage arrives (phone → Bank).
3. Sunday night → Monday 08:00: rent and bills leave the bank. Check the Bank statement.
4. Buy food at the Späti (only while someone is behind the counter), cook at home.
5. Wash your clothes at the Waschsalon; try the clothes rail and the barber; change outfits at
   the wardrobe at home.
6. Read the timetable case on the Hauptstraße or the service board at St. Nikolai, and talk
   to people: follow a clue and search the place it points to (the Notebook on the phone
   keeps track).
7. Then skip work for a few days: a warning, then the sack. Let the money run out and see the
   rent warnings (eviction after three missed weeks: sleeping rough, then the phone's Housing app
   to rent an empty flat).
8. Press F9 whenever something looks wrong: it saves a bug report.
Tell us: did money feel like it mattered? Was anything confusing, too easy or too hard?

## Implementation notes
Built by the architect (Opus) in the cloud session of 3 October 2026, after every other M3
ticket was merged.
- New: `tools/economy_check.gd` (EconomyCheck), `tests/sim/test_economy_check.gd`,
  `tests/sim/test_m3_making_a_living.gd`. Changed: `tools/sim_runner.gd` (`--check-m3`, the
  `economy:` line, `_passes` and `_budget_problems` shared by the three checks).
- 30-day runs with `--check-m3` (three in parallel on the cloud machine):
  - seed 1: PASSED, 0.194 ms per step; employment 100% throughout, nobody broke, 0 evictions.
  - seed 2: PASSED, 0.180 ms per step; employment 90–100%, nobody broke, 0 evictions.
  - seed 3: PASSED, 0.166 ms per step; employment 100%, nobody broke, 0 evictions.
  Shops were staffed 98–100% of their open time; no shifts missed, no firings; 13–22
  promotions; nobody behind on rent.
- `tools/check.sh`: 685 tests pass (this ticket adds 7).
- **For later (balance, not an M3 failure):** money piles up. Over 30 days the town earns
  €24–41k in wages and spends €21–23k (rent €8.4k, bills €1k, shopping €12–13k); the median
  person ends with about €2,400. Residents never get near broke, so nothing tests the safety
  nets (benefit, eviction) in a normal month. Prices and rents are worth tuning when M4 makes
  money a motive (crime): raise rents or add costs, then re-run `--check-m3`.
- **Screenshots and two fixes (3 October, after the merge).** Screenshots do work in the cloud
  under a virtual display (`xvfb-run -a -s "-screen 0 1280x720x24" tools/screenshot.sh ...`;
  Godot falls back to software rendering). Taking the missing M3 ones found two things the
  owner's playtest would have hit:
  - Clicking the ground to walk somewhere far (command mode) ended with free will sending the
    player straight back home on arrival: the ten idle minutes ran from the click. Now
    `WalkToCommand` holds free will (`autonomy_retry_tick`) until IDLE_MINUTES after the
    expected arrival (`WalkToCommand.walk_ticks`). Test:
    `test_free_will_waits_after_a_long_walk_not_from_the_click` (fails without the fix).
    Residents never use WalkToCommand, so the town checks are unchanged.
  - After a skipped shift the notice said "Woke up at 17:00". Now "Back from work at 17:00"
    (and "Stopped work: Hunger is low"): `TimeSkip.end_notice`, tested in `test_sleep_skip.gd`.
  - `--queue` and `--interact` in screenshots now prefer the player's own object (their own
    wardrobe, not a neighbour's locked one).
  - Seen, not fixed: on the town map two stairwell labels run together ("Haus 9,
    stairwellHaus 3, stairwell").
- Not done in the cloud: the owner's playtest above (needed for sign-off and the `m3` tag),
  and an agent playtest (needs OpenCode on the Mac).

## Questions

## Review feedback
