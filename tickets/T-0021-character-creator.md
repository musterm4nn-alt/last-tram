---
id: T-0021
title: Full character creator with live preview and portrait
status: draft
milestone: M1
size: L
owner: builder
depends_on: [T-0020]
builder:
review_rounds: 0
---

## Goal
The name screen grows into the full character creator: name, identity (gender, pronouns), age,
body (height, build, skin tone), face and hair (style, colour, eyes, facial hair, features)
and a starter outfit (item and colour per slot). It has randomise buttons per section and for
everything, and a live preview: the top-down figure in all four directions plus a larger
front-facing portrait ("paper doll").

## Notes for the architect (to detail before this becomes todo)
- Lesson from T-0019 (long hair covered faces, unseen in its three random screenshots):
  require a screenshot that shows **every** option (each hair style, build, facial hair,
  feature and clothing slot), e.g. a debug gallery screen, not only random seeds.
- Split model from UI so most of it is testable headless: `game/ui/creator_model.gd` holds a
  `CharacterSpec` and offers `next(field)`, `previous(field)`, `set_colour(slot, colour)`,
  `toggle_feature(id)`, `randomise(section)`, `randomise_all()`, `errors()`. Tests cover
  cycling through every option list, clamping ranges (age 18–80, height), and that
  randomising a section leaves the other sections alone.
- UI: `game/ui/character_creator.gd` replaces `NameScreen` in the New game flow; sections as
  tabs; ◀ ▶ pickers for option lists, swatches for colours, sliders for age and height.
- Preview: `PersonDrawer2D` (T-0019) at a large scale for the four directions;
  `game/ui/character_portrait.gd` (Control) draws a front-facing portrait from the same
  appearance and outfit data, and will be reused in the wardrobe and inspector.
- Launch options for screenshots: `--screen=creator` plus `--creator-tab=<section>` and
  `--creator-seed=N` (preload a random spec) so each tab can be screenshotted.
- Optional slots can be left empty; required ones (top, bottom, feet) can't.
- Content rules: age can't go below 18; no body-part options beyond height and build.

## Implementation notes

## Questions

## Review feedback
