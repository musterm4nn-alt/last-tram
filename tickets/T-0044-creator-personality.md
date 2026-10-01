---
id: T-0044
title: Personality in the character creator
status: done
milestone: M2
size: S
owner: builder
depends_on: [T-0033]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
A Personality tab in the character creator: seven sliders (−100..100) with plain words at
each end ("cruel ↔ caring"), and a Randomise button. The chosen personality becomes the
player's.

## Read first
- `docs/design/people.md` → "Personality (M2)"
- As merged: `sim/people/personality.gd`, `game/ui/creator_model.gd` (`SECTIONS`,
  `randomise`), `game/ui/creator_clothes_tab.gd` (the separate-tab pattern),
  `game/ui/character_creator.gd` (at the 350-line limit), `tests/game/test_creator_model.gd`

## Scope
Create `game/ui/creator_personality_tab.gd`. Change `game/ui/creator_model.gd`,
`game/ui/character_creator.gd`, `game/main.gd` and `game/launch_options.gd` (docs for
`--creator-tab=personality`), `tests/game/test_creator_model.gd`,
`tests/game/test_character_creator.gd`.
**Out of scope:** traits, showing personality anywhere else.

## Specification
- `CreatorModel`: `SECTIONS` gains `"personality"` **last** (so Randomise everything draws
  the earlier sections as before). `randomise("personality", rng)` →
  `spec.personality = Personality.random(rng)`. `func set_trait(axis: String, value: int)`
  (clamped, through `Personality.set_axis`).
- `CreatorPersonalityTab` (VBoxContainer, like `CreatorClothesTab`): `signal changed`,
  `build(model)`, `sync(model)`. One row per `Personality.AXES` entry: the axis name, the
  low word, an `HSlider` (−100..100, step 5), the high word. Words:
  kindness cruel/caring, honesty deceitful/principled, sociability loner/outgoing,
  ambition idle/driven, temper calm/hot-headed, vice restrained/indulgent, bravery
  timid/bold (a const in the tab). Moving a slider calls `model.set_trait` and emits
  `changed`.
- `CharacterCreator`: `TABS` gains `"personality"`, the tab title is "Personality", and it
  gets a Randomise button like the others. Keep the file within the 350-line lint limit by
  moving the Name tab's construction (`_build_name_tab`, `_field`) into a
  `CreatorNameTab` class if needed.

## Acceptance criteria
- [x] `randomise("personality")` changes only the personality; other sections' randomise
  leave it alone; `randomise_all` with a fixed seed gives the same non-personality result
  as before → `test_creator_model.gd`.
- [x] Moving a slider updates `model.spec.personality`, and the started character has
  it → `test_character_creator.gd` (emit `value_changed`, see the conventions' gotchas).
- [x] `tools/check.sh` passes; screenshot `out/t0044.png` with
  `--screen=creator --creator-tab=personality --creator-seed=3`.

## Implementation notes
- `CreatorPersonalityTab` (`game/ui/creator_personality_tab.gd`) as specified, with one
  deviation: sliders step by **1**, not 5. With 5, a random personality value like 86 showed
  as 85 (caught by `test_personality_tab_has_a_randomise_button_and_follows_the_model`).
- `CreatorModel`: `"personality"` is the last section; `set_trait`.
- To stay under the line limit, the picker and number rows moved into `CreatorRows`
  (`game/ui/creator_rows.gd`) instead of moving the Name tab. That was smaller, since the
  name fields are used all over the screen. `character_creator.gd` is now 327 lines.
- The tab area is 540 px wide (was 430), so all six tab titles fit without scroll arrows.
- Proof that Randomise everything is unchanged for the other sections: a golden test with
  seeds 77 and 5, recorded on main before this change.
- Verified: `tools/check.sh` 384 passed, 0 failed. Screenshots `out/t0044.png` (Personality
  tab, seed 3) and `out/t0044_name.png` (all six tabs visible).

## Questions

## Review feedback
