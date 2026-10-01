---
id: T-0043
title: Scenes - short text moments in a popup
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0038]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Short text pages shown in a popup when an interaction asks for one: the first night in the
flat, a night at the Kneipe, a coffee at Café Wolke. They're the base for the owner's own
content later (docs/design/content-packs.md → "Scenes (M2)"). Scenes never change the sim.

## Scope
Create `data/scenes/core.json`, `sim/content/scene_def.gd`, `presentation_def.gd`,
`scene_loader.gd`, `sim/actions/presentations.gd`, `game/dialogue/scene_text.gd`,
`game/ui/scene_popup.gd`, `tests/game/test_scenes.gd`. Change `sim/content/content_db.gd`,
the interaction def and loader (`presentation`), the interactions data,
`sim/systems/action_system.gd`, `sim/people/person.gd` (`scenes_requested`), the person
validator, `game/main.gd`, `game/launch_options.gd` (`--scene`),
`game/input/player_controller.gd`.
**Out of scope:** images (content holds no art paths yet; that waits for the art direction),
variants, adult scenes (M6), choices with effects.

## Specification
- `SceneDef`: id, adult (must be false in the core), pages (templates). Placeholders:
  {actor}, {target}, {place}, and {actor.they|them|their|themself} (same for target).
  Unknown placeholders are content errors.
- An interaction's `presentation`: scene, when ("finish"), player_only, chance (stream
  "scenes" when below 1), day, once (remembered in `Person.scenes_requested`, saved).
- `Presentations.on_finish` emits `scene_requested` {scene_id, actor_id, target_id, place_id}.
- `ScenePopup`: pages with Next / Continue, pausing while open (the speed comes back after),
  further requests queued, unknown scenes ignored. `SceneText.fill` capitalises a leading
  pronoun.
- Content: first_night_home (sleep, player, day 1, once), night_at_the_kneipe (drink, 25%),
  coffee_at_wolke (coffee, 30%).

## Acceptance criteria (`tests/game/test_scenes.gd`)
- [x] Scenes load; adult scenes, unknown placeholders and empty scenes are rejected.
- [x] Text fills names, places and pronouns ("they" for they/them).
- [x] Over 2 days the first-night scene is requested exactly once, for the player only.
- [x] Requests don't change the sim (same seed, same save).
- [x] The popup pauses, pages through, queues and restores the speed. Screenshot
  `out/t0043.png`.
- [x] `tools/check.sh` passes.

## Implementation notes
- First version requested the first-night scene twice (the player also slept in the daytime
  on day 1), hence `once`.
- Verified: `tools/check.sh` 453 passed, 0 failed.

## Questions

## Review feedback
