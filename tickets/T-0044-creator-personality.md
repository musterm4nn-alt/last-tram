---
id: T-0044
title: Personality in the character creator
status: todo
milestone: M2
size: S
owner: builder
depends_on: [T-0033]
builder:
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
- [ ] `randomise("personality")` changes only the personality; other sections' randomise
  leave it alone; `randomise_all` with a fixed seed gives the same non-personality result
  as before → `test_creator_model.gd`.
- [ ] Moving a slider updates `model.spec.personality`, and the started character has
  it → `test_character_creator.gd` (emit `value_changed`, see the conventions' gotchas).
- [ ] `tools/check.sh` passes; screenshot `out/t0044.png` with
  `--screen=creator --creator-tab=personality --creator-seed=3`.

## Implementation notes

## Questions

## Review feedback
