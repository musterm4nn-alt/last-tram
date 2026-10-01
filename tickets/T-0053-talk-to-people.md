---
id: T-0053
title: Talk to people - click or E opens a person's menu
status: done
milestone: M2
size: S
owner: builder
depends_on: [T-0038]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The player can use the T-0038 social interactions. In command mode, a click on a person
(their figure, not just their feet) opens a menu headed with their name: Chat, Tell a joke,
Compliment, Insult, Argue, Flirt. People take priority over objects and the ground. In direct
mode, E picks whatever is best in reach, person or object, with the same facing bonus. The HUD
says how an exchange went for the player, and when someone does something to them.

## Scope
`game/ui/interaction_menu.gd` (`options`, person headers), `game/input/player_controller.gd`
(`person_at`, `nearest_person`, `nearest_target`, shared scoring), `game/ui/hud.gd`
(`social_notice`, `target_busy` / `target_left` reasons), `tests/game/test_talk_to_people.gd`.

## Acceptance criteria (`tests/game/test_talk_to_people.gd`)
- [x] A person's menu lists their full name and the six interactions; choosing one queues it
  on them.
- [x] A click on a person's figure finds them (not on another floor, never yourself).
- [x] E picks the person in front over an object behind, and vice versa.
- [x] HUD: "Chat with Mira Kovač: went well / didn't go well", "Mira Kovač: Tell a joke", and
  "Chat: they're busy".
- [x] `tools/check.sh` passes.

## Implementation notes
- `nearest_object` now uses the shared `_score` / `_object_score` helpers, with the same
  behaviour (its existing tests pass unchanged).
- No screenshot: the menu is the existing PopupMenu with a different header and items. The
  playbook's play step covers it.
- Verified: `tools/check.sh` 435 passed, 0 failed.

## Questions

## Review feedback
