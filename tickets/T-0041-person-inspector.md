---
id: T-0041
title: Person inspector
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0037, T-0053]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Click anyone in command mode to see, in a panel on the right: name, age and pronouns, mood
(with their moodlets), what they're doing, where they live and with whom, how they see you,
and what they remember about you.

## Scope
Create `game/ui/person_inspector.gd`, `tests/game/test_person_inspector.gd`. Change
`game/ui/hud.gd`, `game/main.gd` (wiring, `--inspect`), `game/launch_options.gd`,
`game/input/player_controller.gd` (a click selects or clears), `data/dialogue/lines.json` and
the dialogue def/loader (`memories`: how a memory kind is worded).

## Acceptance criteria (`tests/game/test_person_inspector.gd`)
- [x] The lines show who they are, their mood, what they're doing, their household, how they
  see you, and "Remembers nothing about you yet" for strangers.
- [x] Memories about you are worded ("laughed at your joke"); moodlets are listed with values.
- [x] Relationship words, from "a stranger" to "a close friend", "can't stand you" and
  "in love with you".
- [x] "Doing" names the action and who it's with, and says when they're on the way.
- [x] The panel shows and hides. Screenshot `out/t0041.png`.
- [x] `tools/check.sh` passes.

## Implementation notes
- A click on a person opens their chat menu (T-0053) and the inspector. A click on the
  ground or an object clears it.
- `--inspect` (screenshots) opens it on the lowest-id resident after the quick start.
- Verified: `tools/check.sh` 448 passed, 0 failed. Screenshot `out/t0041.png` (Mon 21:17):
  Alex Wójcik, 55, Happy (Fresh air +6, Had a laugh +10), sitting outside, Haus 5 1st floor
  left, a stranger to you.

## Questions

## Review feedback
