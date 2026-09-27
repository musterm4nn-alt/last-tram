---
id: T-0029
title: Character creator: Clothes tab and Randomise buttons
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0026]
builder:
review_rounds: 0
---

## Goal
The creator gets its last tab, **Clothes**: for each slot, step through the starter items
(or nothing, for optional slots) and pick a colour from swatches. Every tab gets a
"Randomise" button for its own section, and a "Randomise everything" button sits next to
Start.

## Read first
- T-0021 and T-0026 as merged: `CreatorModel` (`clothing_options`, `clothing`,
  `next_clothing`, `previous_clothing`, `colour_options`, `set_colour`, `randomise`,
  `randomise_all`), `CharacterCreator` (the picker helper, how tabs are built),
  `FigurePreview`
- `sim/content/clothing_def.gd` (`SLOTS`), `ContentDB.clothing` and `clothing_colours`
  (colour ids → `ColorOption` with `name` and `color`)

## Scope
Change `game/ui/character_creator.gd` (if it would pass 350 lines, move the Clothes tab into
`game/ui/creator_clothes_tab.gd`, `CreatorClothesTab extends VBoxContainer`), and
`tests/game/test_character_creator.gd`.
**Out of scope:** non-starter clothes, buying, the wardrobe (M3), the portrait (T-0027).

## Specification
- **Clothes tab** (after "Face & hair"): one row per slot in `ClothingDef.SLOTS` order that
  has at least one starter item: the slot name (capitalised: "Top", "Outer", "Feet"...), an
  item picker (◀ item name or "None" ▶, using `next_clothing`/`previous_clothing`), and a row
  of colour swatches (small `Button`s, 22×22, flat, with a `StyleBoxFlat` in the colour and
  its name as the tooltip) for `colour_options(slot)`. The chosen colour's swatch has a
  2 px light border. Swatches rebuild when the item changes.
- **Randomise buttons:** each tab ends with a "Randomise" button calling
  `model.randomise(<section>, _rng)`; next to Start a "Randomise everything" button calls
  `model.randomise_all(_rng)`. `_rng` is a `RandomNumberGenerator` the creator seeds with
  `randomize()` (or with `--creator-seed` when given, so screenshots are repeatable).
- `--creator-tab=clothes` selects the new tab (extend the tab-name mapping from T-0026).
- After any change, every tab's controls show the model's current values (write one
  `_sync_from_model()` that refreshes pickers, spin boxes, checkboxes and swatches, and call
  it after randomising), and the preview and Start button update.

## Acceptance criteria (`tests/game/test_character_creator.gd`)
- [ ] The Clothes tab has one row per slot with starter items; stepping the "Bottom" picker
  changes `model.clothing("bottom")`; an optional slot can show "None".
- [ ] Pressing a swatch sets that colour in the model and moves the highlight.
- [ ] Each tab's Randomise changes only that section (compare the other sections before and
  after, with a seeded `_rng`), and the controls show the new values afterwards.
- [ ] "Randomise everything" with a seeded `_rng` gives a spec with no `errors()`, and the
  Name tab's fields show the new names.
- [ ] Screenshots (open and look at them): `tools/screenshot.sh out/t0029_clothes.png
  --screen=creator --creator-tab=clothes --creator-seed=7`, and the same with seeds 8 and 9:
  the Clothes tab with swatches and the preview wearing the outfit.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
