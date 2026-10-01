---
id: T-0073
title: A second-hand clothes shop and a barber
status: draft
milestone: M3
size: M
owner: builder
depends_on: [T-0072]
builder:
review_rounds: 0
---

## Goal
You can buy clothes and change your hair. Haus 3's ground floor becomes two shops: a
second-hand clothes shop (buy items at their catalogue prices; they go into your wardrobe)
and a barber (a haircut and colour for a price).

## Read first
`docs/design/character-and-appearance.md` → Changing your look in-game; the cookbook's "Edit
the town map or add a place"; T-0072 (the wardrobe).

## Design (draft: detailed when its dependencies are merged)
- Map: split Haus 3's ground floor (57..70, 6..15) into two shop places with hours
  (`kind: "shop"`), doors and counters; that home's household goes, so 14 neighbour homes
  remain. Check `--check-m2` and the residents count afterwards.
- `BuyClothesCommand(person_id, item_id, colour)` through a shop screen (the clothes tab with
  prices); `Money.spend(…, "purchase", item_id)`.
- Barber: "Get a haircut" (€18, 30 min) opens a hair screen (style and colour from the
  catalogue), then `ChangeHairCommand`.

## Acceptance (sketch)
- Buying adds to the wardrobe and costs the price; you can't buy what you can't afford; a
  haircut changes appearance and costs €18; both shops respect their hours. Screenshots.

## Implementation notes

## Questions

## Review feedback
