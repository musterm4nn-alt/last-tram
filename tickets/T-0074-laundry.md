---
id: T-0074
title: Dirty clothes and the Waschsalon
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0072, T-0064]
builder:
review_rounds: 0
---

## Goal
Clothes get dirty as you wear them, faster at work, and dirty clothes make you feel and look
worse. Washing machines at Waschsalon Blitz clean your whole wardrobe for a few euros. How you
look ("presentation": hygiene, clean clothes, an outfit that fits the place) now affects job
interviews.

## Read first
`docs/design/character-and-appearance.md` → Presentation; T-0064 (the interview), T-0072 (the
wardrobe).

## Design (draft: detailed when its dependencies are merged)
- Dirt per owned item (0..100), rising per hour worn (more at work); saved.
- A "Dirty clothes" moodlet past a threshold, and a small hygiene cost.
- `washing_machine` objects at the Waschsalon: "Wash your clothes" (€4, 60 min) cleans every
  owned item. Residents do laundry by free will when their clothes get dirty.
- `Presentation.of(sim, person) -> float` (derived, not saved): hygiene, dirt, formality
  against the place or job. The interview (T-0064) uses it.

## Acceptance (sketch)
- Dirt rises and washing resets it; the moodlet; presentation with exact numbers; residents
  visit the Waschsalon in a 7-day run.

## Implementation notes

## Questions

## Review feedback
