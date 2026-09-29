---
id: T-0027
title: Front-facing portrait in the creator, and a look gallery for checking every option
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0029]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The creator shows a larger front-facing **portrait** ("paper doll") next to the top-down
preview: head and shoulders with skin, hair style and colour, eyes, facial hair, features
(freckles, glasses, beauty mark) and the top and outer clothes. A **look gallery** screen
draws every option side by side, so one screenshot proves every hair style, build, facial
hair, feature and clothing slot draws sensibly (T-0019 missed long hair covering faces
because random screenshots never showed it).

## Read first
- `docs/design/character-and-appearance.md` → "The character creator"; `docs/art.md` (these
  are placeholders until the art gate: simple shapes, readable, no art assets)
- As merged: `game/view2d/person_drawer_2d.gd` (colour helpers and how hair shapes are
  chosen: `ViewConfig.HAIR_SHAPE`, `BUILD_WIDTH`), `game/ui/character_creator.gd`,
  `game/ui/figure_preview.gd`, `sim/content/appearance_catalog.gd`, `ContentDB.clothing`

## Scope
Create `game/ui/character_portrait.gd` (`CharacterPortrait`), `game/ui/look_gallery.gd`
(`LookGallery`), `tests/game/test_character_portrait.gd`. Change
`game/ui/character_creator.gd` (add the portrait), `game/main.gd` and
`game/launch_options.gd` (`--screen=gallery`), `tests/game/test_launch_options.gd`.
**Out of scope:** real art, animation, the wardrobe and inspector (they will reuse the
portrait later).

## Specification

### `CharacterPortrait` (`extends Control`)
- `func show_look(appearance: Appearance, outfit: Outfit) -> void` stores them and redraws;
  minimum size 200×240. (Not `show()`: that is Control's own method.)
- `_draw()` in this order (all simple shapes, colours from the same helpers as
  `PersonDrawer2D`; move shared colour helpers into public static functions on
  `PersonDrawer2D` if needed, without changing its drawing):
  1. shoulders/torso in the top colour (width by build), with the outer layer as an open
     jacket if worn;
  2. neck and head (an ellipse) in the skin tone;
  3. hair by shape (`ViewConfig.HAIR_SHAPE`): short caps, sides, long (drawn **behind** the
     head and shoulders, never over the face), tail, bun, afro, mohawk, none;
  4. eyes (two small circles in the eye colour), a mouth line;
  5. facial hair by id (a stubble tint, moustache, beard shapes) in the hair colour;
  6. features: freckles (dots), glasses (two rings and a bridge), beauty mark (one dot);
  7. a head item from the "head" slot if worn (a cap/beanie band in its colour).
- Geometry comes from pure static functions that `_draw()` uses (so tests can check it):
  ```gdscript
  ## The head's bounding box for a portrait of this size.
  static func head_rect(size: Vector2) -> Rect2
  ## The face (eyes, nose, mouth) inside the head; hair must never cover it.
  static func face_rect(head: Rect2) -> Rect2
  ## The rectangles each hair shape is drawn inside, in front of the face layer
  ## (hair drawn behind the head, like "long", is not included).
  static func hair_front_rects(shape: String, head: Rect2) -> Array[Rect2]
  ```

### Creator
The portrait sits above the four-direction preview and updates with every change.

### `LookGallery` (`extends CanvasLayer`, opened with `--screen=gallery`)
A grid of portraits and top-down figures, each labelled, starting from the default player's
look and changing one thing at a time: every hair style, every build, every facial hair,
each feature alone and all features together, every skin tone, and one outfit per starter
item of each slot. It must fit on one 1280×720 screenshot (use small portraits, e.g. 64×76,
and several rows), or be split into pages with `--gallery-page=N`.

## Acceptance criteria
- [ ] `tests/game/test_character_portrait.gd`: for every hair style in the catalog (via
  `ViewConfig.HAIR_SHAPE`, unknown → "cap"), no rectangle from `hair_front_rects()`
  intersects `face_rect(head_rect(...))`.
- [ ] The portrait of the default player differs between two hair colours and two skin tones
  (compare the colours the portrait would use, via the helper functions).
- [ ] `test_launch_options.gd`: `--screen=gallery` (and `--gallery-page=2` if you add pages)
  parse.
- [ ] Screenshots (open and look at every one; say in the notes what you checked):
  `tools/screenshot.sh out/t0027_gallery.png --screen=gallery` (plus other pages) showing
  every option, and `tools/screenshot.sh out/t0027_creator.png --screen=creator
  --creator-seed=7` with the portrait above the preview.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- `game/ui/character_portrait.gd` (`CharacterPortrait`, `show_look()`): head and shoulders
  sized from the control: hair behind (long, tail, afro), neck, top with an open outer
  layer, scarf/chain band, head, eyes in their colour, mouth, facial hair (stubble is an
  unoutlined chin tint; with an outline it looked like a blob), freckles, glasses, beauty
  mark, front hair, then cap/beanie and sunglasses. Geometry comes from the pure
  `head_rect()`, `face_rect()`, `hair_front_rects()`.
- `PersonDrawer2D` gains public `skin_color`, `hair_color`, `eye_color`, `worn_color`
  (its own drawing is unchanged).
- The creator shows the portrait above the four-way preview (the file is at the 350-line
  limit now; the next creator change should move a tab out like the Clothes tab).
- `game/ui/look_gallery.gd` (`LookGallery`, `--screen=gallery`, `--gallery-page=2`): page 1
  shows every hair style, build, facial hair, each feature and all together, and every skin
  tone; page 2 shows one outfit per starter item.
- Tests: `tests/game/test_character_portrait.gd` (4: front hair never meets the face for
  every hair style at three sizes, colour lookups, the gallery covers every option with
  valid characters) and one in `test_launch_options.gd`. `tools/check.sh`: 282 passed.
- Screenshots: `out/t0027_gallery1.png` and `out/t0027_gallery2.png` (every option,
  checked by eye: long hair stays behind the face, beards and glasses read clearly,
  sunglasses and caps sit right), `out/t0027_creator.png` (portrait above the preview).
- Known limit: gloves and bags are not drawn (neither portrait nor top-down figure).

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
