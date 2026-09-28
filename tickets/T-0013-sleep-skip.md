---
id: T-0013
title: Fast-forward while the player sleeps
status: done
milestone: M1
size: S
owner: builder
depends_on: [T-0006, T-0028]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
While the player sleeps, time runs much faster (120×, a night in about four seconds) until
they wake up, you cancel, or a need gets critical (`docs/design/time-and-speed.md` → "Skip"). The HUD shows
"▶▶ skipping". Which actions skip time is data (`"time_skip": true` on sleep), not code.

## Read first
- `docs/design/time-and-speed.md` → "Speeds" (the Skip row)
- As merged: `game/session.gd` (`_process`, `speed`, `MAX_STEPS_PER_FRAME`, `notice`),
  `game/ui/hud.gd` (the clock label), `sim/content/interaction_def.gd` and
  `sim/content/interaction_loader.gd`, `data/interactions/basics.json`, `sim/actions/action.gd`
  (`state`, `started_tick`), the `need_critical` event (`{"person_id", "need"}`, from
  `NeedsSystem` when a need drops below its `critical_below`)
- `tests/game/test_objects_view_2d.gd` (swapping `Session` state in tests)

## Scope
Change `sim/content/interaction_def.gd`, `sim/content/interaction_loader.gd`,
`data/interactions/basics.json`, `game/session.gd`, `game/ui/hud.gd`; create
`tests/game/test_sleep_skip.gd`; extend `tests/sim/test_actions.gd` with the loader check.
**Out of scope:** skipping for other actions, a skip button, skipping to an alarm time.

## Specification

### Data
- `InteractionDef.time_skip: bool = false` (## "While the player performs this, the game
  runs at Session.SKIP_SPEED").
- `InteractionLoader`: optional key `"time_skip"`; when present it must be a bool
  (`reader.read_bool`), otherwise it stays false.
- `basics.json`: sleep gets `"time_skip": true`.

### Session
```gdscript
## Game speed while the player does a time_skip action (like sleeping).
const SKIP_SPEED: int = 120
## True while time runs at SKIP_SPEED (read by the HUD).
var skipping: bool = false
## started_tick of the action whose skipping was stopped by a critical need (-1 = none),
## so the same sleep does not start skipping again.
var _skip_stopped_tick: int = -1

## True when the player's front action is PERFORMING an interaction with time_skip, the
## game is not paused, and skipping was not stopped for this action (stopped_tick).
static func should_skip(sim: Sim, speed: int, stopped_tick: int) -> bool
```
- `_process`: set `skipping = should_skip(sim, speed, _skip_stopped_tick)` before stepping,
  and step with `SKIP_SPEED` instead of `speed` while skipping (the existing
  `MAX_STEPS_PER_FRAME` cap stays).
- While draining events: a `need_critical` for the player while `skipping` stops it:
  `_skip_stopped_tick = <front action>.started_tick`, `skipping = false`, and
  `notice.emit("Woke up: %s is low" % <need name>)` (the need's `name` from content).
- `speed` is never changed by skipping; when the sleep ends or is cancelled, the old speed
  simply applies again.

### Hud
The clock label shows `"▶▶ skipping"` instead of `"1x"` / `"2x"` / `"3x"` while
`Session.skipping`.

## Acceptance criteria
- [ ] `tests/game/test_sleep_skip.gd` (set `Session.sim` to a `from_rows` room with a bed,
  the player on its slot; restore `Session.sim`, `speed` and `_skip_stopped_tick` after each
  test):
  - `should_skip` is true while sleeping at speed 1, false while paused, false for watch_tv,
    false while the sleep is only ROUTING, false with `stopped_tick` equal to the sleep's
    `started_tick`.
  - Calling `Session._process(0.05)` while sleeping at speed 1 runs 120 steps (6 game
    minutes) instead of 1; after the sleep finishes, the next `_process(0.05)` runs 1 step
    (check `Session.steps_last_frame`).
  - A need crossing `critical_below` during the skipped sleep (set hunger to 15.05) stops
    skipping, emits the notice "Woke up: Hunger is low", and skipping does not restart for
    that sleep.
- [ ] `tests/sim/test_actions.gd`: sleep's `time_skip` is true and watch_tv's is false; a
  broken-fixture entry with `"time_skip": "yes"` is reported (add it to
  `tests/fixtures/content_broken/interactions/broken.json`).
- [ ] Screenshot: `tools/screenshot.sh out/t0013.png --queue=bed_double:sleep --advance=5`
  (`--queue` is T-0028's launch option) shows "▶▶ skipping" in the clock box and the player
  on the bed's slot. Open the PNG and look at it.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- Data: `InteractionDef.time_skip` (optional bool in the loader); sleep has it.
- `Session`: `SKIP_SPEED` 120, `skipping`, `should_skip(sim, speed, stopped_tick)` (static;
  parameters named `p_sim`/`p_speed` so they don't shadow Session's own fields). The step
  rate uses 120x while skipping (the 200-steps-per-frame cap stays). The player's
  `need_critical` while skipping stops it for that sleep and shows "Woke up: Hunger is low".
- HUD: the clock shows "▶▶ skipping".
- Tests: `tests/game/test_sleep_skip.gd` (3) and two checks in `test_actions.gd` (which
  interactions skip; a broken `"time_skip": "yes"` is reported). `tools/check.sh`: 247
  passed, 0 failed.
- Screenshot `out/t0013.png` (`--queue=bed_double:sleep --advance=5`): "Mon 08:34 ▶▶
  skipping", the player at the bed, Sleep in the queue panel, ▲ on Energy and Comfort.

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
