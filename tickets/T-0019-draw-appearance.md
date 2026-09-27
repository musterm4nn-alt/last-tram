---
id: T-0019
title: Draw people from their appearance and outfit (placeholders)
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0018]
builder:
review_rounds: 0
---

## Goal
The placeholder figures show who people are: skin tone, hair style and colour, build and
height, facial hair, glasses, and clothes in their colours. The player is marked with a small
yellow marker instead of a yellow body. The drawing code is reusable, because the character
creator (T-0021) will draw the same figure in its preview.

## Read first
- `docs/design/character-and-appearance.md`, `docs/art.md` → "Now: placeholders on purpose"
- `game/view2d/person_view_2d.gd` (you replace its `_draw`), `game/view2d/view_config.gd`,
  `game/main.gd` (command-line options)
- T-0018 as merged: `person.appearance` is an `Appearance` (`skin_tone`, `height_cm`,
  `build`, `hair_style`, `hair_colour`, `eye_colour`, `facial_hair`, `features`);
  `person.outfit.get_item(slot)` returns a `WornItem` (`clothing_id`, `colour`) or null when
  nothing is worn there; `Session.new_game(seed_value, spec)` takes a `CharacterSpec`.

## Scope
Create `game/view2d/person_drawer_2d.gd`. Change `game/view2d/person_view_2d.gd`,
`game/view2d/view_config.gd`, and `game/main.gd` (one new option).
**Out of scope:** anything in `sim/`, animation, real art, portraits (T-0021).

## Specification
- `PersonDrawer2D` (RefCounted, static only):
  ```gdscript
  ## Draws a top-down placeholder person with their feet at (0, 0) on `canvas`.
  static func draw(canvas: CanvasItem, content: ContentDB, appearance: Appearance,
          outfit: Outfit, facing: Vector2, px: float, is_player: bool) -> void
  ```
  `PersonView2D._draw()` becomes one call to it.
- Proportions: body width from the build (`ViewConfig.BUILD_WIDTH`, in cells: slim 0.44,
  average 0.52, athletic 0.56, stocky 0.60, heavy 0.66; unknown id → 0.52); body height
  `0.9 × height_cm / 175`.
- Layers, back to front: shadow → shoes (feet colour) → legs (bottom colour, lower ~45% of
  the body) → torso (top colour) → outer layer if worn (outer colour; when facing down, leave
  a 2 px stripe of the top visible in the middle, like an open jacket) → head (skin tone) →
  hair (see below) → facial hair (a darker arc on the lower head, not when facing up) →
  glasses (the `glasses` feature: two tiny dark squares when facing down, one at the side) →
  head item (a cap/beanie band in its colour) → player marker (a small yellow triangle
  above the head, `ViewConfig.PLAYER_MARKER_COLOR`).
- Hair by style: map style id → shape in `ViewConfig.HAIR_SHAPE` (unknown id → "cap"):
  `bald`→none, `buzz`→thin cap, `short`/`side_part`/`undercut`/`curly_short`→cap,
  `bob`/`shoulder`→cap plus sides, `long`/`braids`/`dreadlocks`→cap plus long back,
  `ponytail`→cap plus tail, `bun`→cap plus bun, `afro`→big round, `mohawk`→centre stripe.
  Facing up (walking away) shows the back of the head: hair covers the whole head circle
  unless bald.
- Colours come from lookups in the `content` parameter (`PersonView2D` passes
  `Session.content`): `content.appearance.skin_tones[id].color`, `hair_colours`,
  `eye_colours`, and `content.clothing_colours[worn.colour].color` for clothes, with a
  visible fallback (magenta) for unknown ids so mistakes show up in screenshots.
- `game/main.gd`: new option `--random-character`. The quickstart new game uses
  `CharacterSpec.random(Session.content, rng)` with an RNG seeded from `--seed`. Document it
  in the option list at the top of the file.

## Acceptance criteria
- [ ] `tools/screenshot.sh out/t0019_default.png --zoom=4` shows the default player (dark
  brown short hair, black t-shirt under a grey hoodie, denim jeans, white trainers) with the
  yellow marker.
- [ ] `tools/screenshot.sh out/t0019_seed{1,2,3}.png --zoom=4 --random-character --seed={1,2,3}`
  show three clearly different people (skin, hair, clothes).
- [ ] `tools/screenshot.sh out/t0019_back.png --zoom=4 --walk=0,-1 --frames=40` shows the back
  of the head (hair covering the head).
- [ ] Open every PNG, and in your notes describe what you see in each and whether it matches.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
