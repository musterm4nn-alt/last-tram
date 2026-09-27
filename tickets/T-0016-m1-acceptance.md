---
id: T-0016
title: M1 acceptance: a day at home, proven headless, plus the owner's playtest checklist
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0009, T-0010, T-0011, T-0012, T-0013, T-0014, T-0015, T-0021, T-0023, T-0024, T-0025, T-0026, T-0027, T-0028, T-0029]
builder:
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
- [ ] `tests/sim/test_m1_day_at_home.gd` passes with the thresholds above for all three
  seeds (paste the printed min/avg lines in the notes).
- [ ] `tools/simrun.sh --days=3` prints the needs summary and the action counts (paste them
  in the notes); `tools/simrun.sh --days=1 --no-free-will` shows needs falling instead.
- [ ] If any data was tuned, the notes list every change with before → after and why.
- [ ] The playtest checklist is in the notes.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
