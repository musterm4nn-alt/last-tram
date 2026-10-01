---
id: T-0050
title: R/F for floors (MacBooks have no Page Up/Down), and sleep jumps straight to waking
status: done
milestone: M2
size: S
owner: builder
depends_on: [T-0049]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
From the owner (playing on a MacBook): "I don't have Page Up and Down", and "when you go to
sleep, skip ahead to the time when you wake up". R and F do what Page Up / Page Down do.
Sleeping no longer fast-forwards for seconds: the game jumps to the moment the sleep ends,
in one frame. A critical need still wakes the player early (T-0013).

## Scope
Change `game/input/input_actions.gd`, `game/session.gd`, `game/ui/hud.gd` (hints),
`docs/design/controls-and-ui.md`, `tests/game/test_sleep_skip.gd` (the 120×-per-frame
expectations become "the whole sleep in one frame"), `tests/game/test_floor_view.gd`.
**Out of scope:** skipping other actions; a fade or "zzz" screen.

## Specification
- `"level_up": [KEY_PAGEUP, KEY_R]`, `"level_down": [KEY_PAGEDOWN, KEY_F]`. Hints: "R/F stairs"
  (direct) and "R/F floors" (command).
- `Session`: while `skipping`, one frame runs steps until the skip ends (the sleep finishes,
  is cancelled or replaced, or a critical need stops it), at most `SKIP_MAX_STEPS` (one game
  day) per frame, ignoring `MAX_STEPS_PER_FRAME`. The per-step checks, event forwarding and
  command logging stay as they are. When a skip ends because the sleep finished, the HUD
  notice says "Woke up at <Day HH:MM>". `SKIP_SPEED` is removed.

## Acceptance criteria
- [x] One frame of a sleep runs it to the end; the next frame is back to 1× →
  `test_sleep_skip.gd`.
- [x] A critical need still stops the skip at the event, and the cancel/replace cases still
  discard the skip → `test_sleep_skip.gd` (unchanged tests).
- [x] "Woke up at ..." after a normal wake-up → `test_sleep_skip.gd`.
- [x] R/F are bound to the floor actions → `test_floor_view.gd`.
- [x] `tools/check.sh` passes.

## Implementation notes
- Keys: `level_up` = Page Up or R, `level_down` = Page Down or F; HUD hints and the controls
  doc say R/F.
- `Session`: `SKIP_SPEED` replaced by `SKIP_MAX_STEPS` (one game day). While skipping, the
  frame's budget is the full cap and the loop's existing per-step stop checks end it. The
  notice "Woke up at <Day HH:MM>" appears whenever a skip ends without a critical need
  (a finished, cancelled or replaced sleep). A critical need keeps its "Woke up: <need> is
  low" notice.
- `test_sleep_skip.gd`: the two tests that asserted 120 steps per frame (the old T-0013 speed)
  now assert the whole sleep in one frame, as the owner asked. The critical-need, cancel and
  finish tests are unchanged and pass.
- Verified: `tools/check.sh` 385 passed, 0 failed. Real game (`out/t0050.png`): queued sleep
  at about 08:02, and the next screenshot shows 09:49 with "Woke up at Mon 09:48", full energy,
  and free will cooking. A night is about 10,000 steps, a fraction of a second at
  0.006 ms per step.

## Questions

## Review feedback
