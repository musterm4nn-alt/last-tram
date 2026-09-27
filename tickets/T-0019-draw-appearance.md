---
id: T-0019
title: Draw people from their appearance and outfit (placeholders)
status: review
milestone: M1
size: M
owner: builder
depends_on: [T-0018]
builder: OpenCode / Muse Spark 1.3 Free
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
- Colours come from content lookups (`Session.content.appearance.skin_tones[id].color`,
  `Session.content.clothing_colours[id].color`, ...), with a visible fallback (magenta) for
  unknown ids so mistakes show up in screenshots.
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
Implemented on branch `t/0019-draw-appearance`, stacked on unmerged `t/0018-character-model`
(T-0019 needs the T-0018 model classes; rebase onto main once T-0018 merges).
- New: `game/view2d/person_drawer_2d.gd` (`PersonDrawer2D`, RefCounted, static `draw`
  exactly per the spec signature; feet at (0, 0); layers shadow → shoes → legs → torso →
  outer (2 px top stripe when facing down) → head → hair → facial hair → glasses →
  head item → yellow player marker; magenta `UNKNOWN_ID_COLOR` fallback for bad ids).
- Changed: `ViewConfig` (+ `BUILD_WIDTH`/`DEFAULT_BUILD_WIDTH`, `HAIR_SHAPE`,
  `PLAYER_MARKER_COLOR`, `UNKNOWN_ID_COLOR`; removed the now-unused `PLAYER_COLOR`,
  `NPC_COLOR`, `SKIN_COLOR`); `PersonView2D._draw()` is one `PersonDrawer2D.draw` call;
  `game/main.gd` documents and handles `--random-character`
  (`CharacterSpec.random(Session.content, rng)` seeded from `--seed`).
- New headless test `tests/game/test_person_draw_tables.gd`: every catalog build has a
  sane width, every hair style maps to a known shape (drawing itself is verified by
  screenshots, which can't run headless).
- Verified: `tools/check.sh` → 83 passed, 0 failed.
- Screenshots (all opened and inspected):
  - `out/t0019_default.png`: default Alex — dark-brown short-hair cap, skin face, grey
    hoodie with a thin black top stripe down the middle, denim legs, white trainers,
    yellow triangle marker above the head. Matches.
  - `out/t0019_seed{1,2,3}.png`: three clearly different people (seed1: darker skin,
    navy/red clothes and dark shoes; seed2: lighter skin, green-tinted hair, grey top,
    black bottom, red shoes; seed3: slim build, red cap of hair, navy top, black
    bottom). Matches.
  - `out/t0019_back.png` (`--walk=0,-1 --frames=40`): player walked north, facing away;
    the head circle is fully covered in dark-brown hair, no face. Matches.
- Bug found while looking at the first screenshots: the open-jacket stripe was drawn
  2 cells wide instead of 2 px, hiding the outer layer. Fixed (`2.0 / px` cells) and
  re-took all screenshots.
- Left for the reviewer: `docs/art.md` still describes the old placeholder ("The player
  is yellow, NPCs blue"); not touched since docs edits are outside this ticket's scope.

## Questions

## Review feedback
