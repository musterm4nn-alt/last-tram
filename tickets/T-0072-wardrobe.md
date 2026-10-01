---
id: T-0072
title: The wardrobe - owned clothes and saved outfits
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0055]
builder:
review_rounds: 0
---

## Goal
Clothes become things you own. Everyone has a wardrobe of clothes (starting with their outfit
and a few starter pieces) and saved outfits ("Everyday", "Work", "Going out"). A wardrobe at
home lets you change clothes or put on a saved outfit.

## Read first
`docs/design/character-and-appearance.md` → Clothes and outfits; `sim/people/outfit.gd`,
`game/ui/creator_clothes_tab.gd`.

## Design (draft: detailed when its dependencies are merged)
- `Person.wardrobe`: owned items (item id + colour), and `Person.outfits` (name → Outfit),
  saved (version bump; migration: owned = what they wear).
- A `wardrobe` object in every flat (placements) with "Change clothes": a screen that reuses
  the creator's clothes tab limited to owned items, then `ChangeOutfitCommand` (validated
  against the wardrobe and `CharacterSpec`'s always-worn rule).
- Residents put on their "Work" outfit for work if they have one (optional, simple).

## Acceptance (sketch)
- You can wear only what you own; saved outfits round-trip; the command validates; screenshot
  of the wardrobe screen.

## Implementation notes

## Questions

## Review feedback
