---
id: T-0016
title: M1 acceptance: a day at home, proven headless, plus the owner's playtest checklist
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0009, T-0010, T-0011, T-0012, T-0013, T-0014, T-0015, T-0021, T-0023, T-0024, T-0025, T-0026, T-0027, T-0028, T-0029]
builder: Claude Code subagent / Sonnet 5 (claude-sonnet-5)
review_rounds: 0
---

## Goal
Prove M1's "done when" (`docs/roadmap.md`): with free will on, the player lives three game
days in the flat with every need out of the red; saving and loading mid-action continues
identically; and the headless sim report shows it. The ticket ends with the checklist the
owner plays through before M1 is closed.

## Read first
- `docs/roadmap.md` → "M1 · A Day at Home" (Done when)
- As merged: `tools/sim_runner.gd` and `tools/simrun.sh`, `sim/systems/autonomy_system.gd`
  and `sim/commands/set_free_will_command.gd` (T-0025), `sim/ai/autonomy.gd` (T-0012),
  `data/interactions/*.json`, `data/needs.json`, `tests/sim/test_save.gd`

## Scope
Change `tools/sim_runner.gd` and `tools/simrun.sh` (comments); create
`tests/sim/test_m1_day_at_home.gd`. If (and only if) a threshold below fails, tune numbers in
`data/interactions/*.json` (rates, durations, `finish_needs`, `advertise`) and record every
change and its effect in the notes. Anything else (code, autonomy constants, needs.json)
is out of scope: set `blocked` and ask.
**Out of scope:** new objects or interactions, NPCs, balance for later milestones.

## Specification

### `tools/simrun.sh` / `sim_runner.gd`
- `--no-free-will`: at the start, `SetFreeWillCommand(player, false)`.
- At the end, a needs summary, one line per need:
  `hunger   min 41.2  avg 71.5  below 30: 0.0% of minutes`, sampled every game minute;
  then one line counting finished actions by interaction (from `action_finished` events,
  drained every minute), e.g. `actions: sit 25, watch_tv 16, cook_meal 8, ...`.

### `tests/sim/test_m1_day_at_home.gd`
- **Three days, three seeds:** for seeds 1, 2 and 3: `SimFactory.new_game(content(), seed)`,
  no input, run 3 × 1440 game minutes, sampling every minute. Every need stays at or above
  15 (never critical) the whole time, and each need is below 30 for at most 5% of the
  minutes. At least 6 different interactions finish. Print each seed's min and average per
  need in the test output (so the review can see the margins).
- **Save mid-sleep:** from a new game (seed 1), run until the player's front action is
  `sleep` in state PERFORMING (fail if that never happens within 2 days), save, load, run
  another 600 minutes, and compare with an uninterrupted run of the same total length
  (`SaveCodec.to_json` equal).
- **Free will off:** with `SetFreeWillCommand(player, false)`, 1 day: the player never acts,
  and at least one need falls below 30 (so the three-day result above really is free will's
  doing).
- Keep the whole file under 10 seconds of test time (check with `tools/test.sh
  --filter=m1_day`); the three runs are pure sim, no rendering.

### The owner's playtest checklist (write it into this ticket's notes, for the final review)
A numbered list in plain words the owner can follow in the real game, covering: start a new
game and create a character in the creator (every tab, randomise, the portrait); walk with
WASD; Tab to command mode, pan, click the ground to walk; open an object's menu by clicking
and with E; queue three things and cancel one; watch needs rise and the ▲ arrows; sleep and
see the skip; leave the character alone with free will on for a game hour; turn free will
off in the Esc menu; save to a slot, load it, and see that the action continues; press F9
and note the folder name it shows.

## Acceptance criteria
- [x] `tests/sim/test_m1_day_at_home.gd` passes with the thresholds above for all three
  seeds (paste the printed min/avg lines in the notes).
- [x] `tools/simrun.sh --days=3` prints the needs summary and the action counts (paste them
  in the notes); `tools/simrun.sh --days=1 --no-free-will` shows needs falling instead.
- [x] If any data was tuned, the notes list every change with before → after and why.
- [x] The playtest checklist is in the notes.
- [x] `tools/check.sh` passes.

## Implementation notes

Added the seed/day/save/free-will proof for M1's "done when" without touching any code
outside the ticket's scope. No data tuning was needed: every threshold passed on the first
run at the current `data/interactions/*.json` and `data/needs.json` numbers.

**Files changed:**
- `tools/sim_runner.gd`: added `--no-free-will` (submits `SetFreeWillCommand(player, false)`
  before the run starts) and, at the end of the run, a needs summary (min/avg/percent-below-30
  per need, sampled every game minute) and an `actions: id count, ...` line tallying the
  player's `action_finished` events (drained every minute), sorted by count descending.
- `tools/simrun.sh`: comment-only, documents the new flag and the two acceptance invocations.
- `tests/sim/test_m1_day_at_home.gd` (new): three tests.
  1. `test_three_days_three_seeds_keep_every_need_out_of_the_red` — for seeds 1, 2, 3: a
     fresh game, no input, 3 × 1440 minutes, sampled every minute. Asserts every need's
     minimum stays ≥ 15 (never critical), each need is below 30 for at most 5% of sampled
     minutes, and at least 6 distinct interactions finish. Prints each seed's per-need
     min/avg/below-30% lines.
  2. `test_save_mid_sleep_and_continue_equals_an_uninterrupted_run` — runs a new game (seed 1)
     until the player's front action is `sleep` in state `PERFORMING` (fails if that never
     happens within 2 game days), saves, loads, runs 600 more minutes, and compares
     `SaveCodec.to_json` against an uninterrupted run of the same total length.
  3. `test_free_will_off_leaves_the_player_idle_and_a_need_falls` — with free will off via
     `SetFreeWillCommand`, runs one day and asserts the player's action queue is empty every
     minute (never acts) and that at least one need fell below 30.

**Commands run and output:**

`tools/test.sh --filter=m1_day` (the three new tests; ~1.4s total, well under the 10s budget):

```
    seed 1: hunger   min 52.4  avg 80.3  below 30: 0.0% of minutes
    seed 1: energy   min 59.4  avg 81.4  below 30: 0.0% of minutes
    seed 1: hygiene  min 53.3  avg 81.2  below 30: 0.0% of minutes
    seed 1: fun      min 39.8  avg 66.4  below 30: 0.0% of minutes
    seed 1: social   min 53.8  avg 80.6  below 30: 0.0% of minutes
    seed 1: comfort  min 46.3  avg 73.1  below 30: 0.0% of minutes
    seed 2: hunger   min 49.8  avg 79.1  below 30: 0.0% of minutes
    seed 2: energy   min 64.4  avg 83.4  below 30: 0.0% of minutes
    seed 2: hygiene  min 49.3  avg 77.8  below 30: 0.0% of minutes
    seed 2: fun      min 46.6  avg 71.4  below 30: 0.0% of minutes
    seed 2: social   min 51.7  avg 78.9  below 30: 0.0% of minutes
    seed 2: comfort  min 54.7  avg 73.7  below 30: 0.0% of minutes
    seed 3: hunger   min 40.0  avg 79.3  below 30: 0.0% of minutes
    seed 3: energy   min 58.3  avg 81.7  below 30: 0.0% of minutes
    seed 3: hygiene  min 55.1  avg 81.0  below 30: 0.0% of minutes
    seed 3: fun      min 42.4  avg 70.0  below 30: 0.0% of minutes
    seed 3: social   min 59.1  avg 83.2  below 30: 0.0% of minutes
    seed 3: comfort  min 53.3  avg 72.9  below 30: 0.0% of minutes
  ok    sim/test_m1_day_at_home.gd :: test_three_days_three_seeds_keep_every_need_out_of_the_red
  ok    sim/test_m1_day_at_home.gd :: test_save_mid_sleep_and_continue_equals_an_uninterrupted_run
  ok    sim/test_m1_day_at_home.gd :: test_free_will_off_leaves_the_player_idle_and_a_need_falls
== 3 passed, 0 failed ==
LAST_TRAM_TESTS: PASSED
```

`tools/simrun.sh --days=3` (needs summary + action counts, default seed 1, free will on):

```
hunger   min 52.4  avg 80.3  below 30: 0.0% of minutes
energy   min 59.4  avg 81.4  below 30: 0.0% of minutes
hygiene  min 53.3  avg 81.2  below 30: 0.0% of minutes
fun      min 39.8  avg 66.4  below 30: 0.0% of minutes
social   min 53.8  avg 80.6  below 30: 0.0% of minutes
comfort  min 46.3  avg 73.1  below 30: 0.0% of minutes
actions: sit 25, watch_tv 16, cook_meal 10, take_shower 8, video_call 7, sleep 6, nap 3, browse_web 2, grab_snack 2
LAST_TRAM_SIMRUN: OK
```

`tools/simrun.sh --days=1 --no-free-will` (the contrast case — needs fall instead of being
looked after):

```
hunger   min 0.0  avg 22.2  below 30: 65.3% of minutes
energy   min 0.0  avg 29.6  below 30: 53.8% of minutes
hygiene  min 0.0  avg 33.3  below 30: 48.0% of minutes
fun      min 0.0  avg 22.2  below 30: 65.3% of minutes
social   min 0.0  avg 33.3  below 30: 48.0% of minutes
comfort  min 0.0  avg 16.6  below 30: 74.0% of minutes
actions: none
LAST_TRAM_SIMRUN: OK
```

`tools/check.sh` (full suite, import + tests + lint):

```
== 285 passed, 0 failed ==
LAST_TRAM_TESTS: PASSED
```

**Data tuning:** none. Every threshold (never below 15, below-30 for at most 5% of minutes,
at least 6 distinct finished interactions) passed at the current `data/interactions/*.json`
and `data/needs.json` numbers for all three seeds, so nothing in `data/` was changed.

**The owner's playtest checklist (M1 sign-off):**

1. From the main menu, start a new game.
2. In the character creator, type a name and go through every tab (Name, Identity, Body,
   Face & hair, Clothes); step through the options with ◀ ▶, pick clothes colours from the
   swatches, try each tab's Randomise and "Randomise everything", and check that the
   portrait and the four small figures change with every choice.
3. Confirm the character and enter the flat.
4. Walk around with W/A/S/D.
5. Press Tab to enter command mode; pan the camera; click a spot on the ground and watch
   your character walk there.
6. Click an object (e.g. the fridge) to open its menu; also stand near an object and press
   E to open the same menu directly.
7. Queue three different actions from the menu (they should appear in the action queue
   panel), then cancel one of the still-queued ones.
8. Let the character use objects and watch the needs panel: needs should rise and show the
   ▲ arrow while an action is filling them.
9. Queue Sleep on the bed and watch time fast-forward (skip) until morning.
10. Leave the character alone (no input) with free will on for one in-game hour and watch
    them pick something to do on their own once they've been idle for a bit.
11. Open the Esc menu and turn free will off; confirm the character now just stands still
    even if a need is low.
12. Save to a slot from the Esc menu, then load that slot; confirm the character's current
    action continues from where it was (e.g. still sleeping, or still walking to the same
    spot) rather than restarting.
13. Press F9 and note the folder name it prints (the bug-report folder), so anyone can find
    the report and replay it later.

## Questions

## Review feedback

**Round 1 (architect): passed; one fix by the reviewer.** Built by a Claude Code subagent
(Sonnet 5) on its own branch, then reviewed like any builder's ticket. Clean, in-scope work;
the tests prove the roadmap's "done when" over three seeds (lowest need 39.8, nothing
below 30), the mid-sleep save round trip, and the free-will-off contrast; no data tuning
was needed. `tools/check.sh` rerun by the reviewer: 285 passed, 0 failed.
- Fixed: checklist step 2 asked the owner to "open the look gallery and pick a saved look",
  which the game doesn't have (the gallery is a checking screen); it now walks through the
  creator's real tabs, swatches and Randomise buttons.

