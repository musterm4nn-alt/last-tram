---
id: T-0090
title: Draw Alex Novak's default character sprite
status: review
milestone: M4
size: M
owner: architect
depends_on: [T-0088]
builder: Codex (owner-requested art work)
review_rounds: 0
---

## Goal

Give the default adult player, Alex Novak, an original editable sprite in the chosen
custom art palette, with idle and walking poses in four directions.

## Read first

- [Art direction](../docs/art.md)
- [Default player](../data/appearance/default_player.json)
- [Custom palette](../art/src/custom/draw_custom.lua)

## Scope

Original art under `art/src/custom/characters/` and `art/export/custom/characters/`,
an asset README, and native Godot resource validation in `tests/game/`.
The owner explicitly requested this art from Codex using Aseprite MCP or JavaScript.
Runtime character-renderer integration and supporting every character-creator combination
are separate work; this is Alex's default look.

## Specification

16×32 RGBA frames with transparent backgrounds. Alex wears the default grey open hoodie,
black T-shirt, denim jeans and white trainers, with short dark-brown hair and olive skin.
Only colours from the route B `P` table are used, including its nearest skin/denim shades.
Six editable layers; eight animation tags: idle/walk × down/up/left/right.
Idle uses two frames, walking four frames at 120 ms. Feet origin: (8,31).
Provide `.aseprite`, PNG + JSON atlas, Godot `SpriteFrames`, and visual/animated previews.

## Acceptance criteria

- [x] The sprite follows Alex's default look and remains readable at native size → reviewed PNG and animated previews.
- [x] Four directions each have a two-frame idle and a four-frame walk → Aseprite metadata and Godot asset tests.
- [x] Atlas regions keep the 16×32 canvas and feet alignment; backgrounds are transparent → Godot asset tests and MCP validation.
- [x] All opaque pixels use route B's palette → Godot asset test.
- [x] Sources remain editable by clothing slot, skin and hair → Aseprite metadata.
- [x] The project imports and the existing suite passes → `tools/check.sh`.

## Implementation notes

Created original pixel art with the checked-in, dependency-free JavaScript authoring
script and Aseprite MCP. Source: `art/src/custom/characters/alex_novak.aseprite`;
PNG/JSON atlas, native Godot `SpriteFrames` and previews: `art/export/custom/characters/`.
Six editable layers, 24 untrimmed 16×32 frames, eight idle/walk tags, 17 route B colours.
The feet slice preserves pivot (8,31); at least one shoe stays on row 30 in every pose.
Black T-shirt remains under the grey hoodie. Left-facing poses mirror the right-facing poses.

Validation:
- `tools/check.sh`: **725 passed, 0 failed**, including the three new asset tests.
- After the final feet/pivot refinements, `tools/check.sh --filter=alex_novak`:
  **3 passed, 0 failed**. The final tests check animation timing, untrimmed atlas regions,
  source/export feet pivot, a planted shoe, transparent bottom row, binary alpha and palette.
- Aseprite MCP game-export validation: **passed**, no errors or warnings.
- Viewed the Aseprite preview, the full pose sheet and the animated walks against the
  existing town's cobblestone, lamp and bench, including at native scale.
- `git diff --check`: clean.

Runtime integration remains separate: `PersonDrawer2D` still draws the existing people.
No simulation, saved appearance data or existing art was changed. Awaiting the owner's
visual review before any merge.

## Questions

## Review feedback
