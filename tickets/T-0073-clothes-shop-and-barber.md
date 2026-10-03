---
id: T-0073
title: A second-hand clothes rail and a barber (at Waschsalon Blitz)
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0072]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
You can buy clothes and change your hair. Haus 3's ground floor becomes two shops: a
second-hand clothes shop (buy items at their catalogue prices; they go into your wardrobe)
and a barber (a haircut and colour for a price).

## Read first
`docs/design/character-and-appearance.md` → Changing your look in-game; the cookbook's "Edit
the town map or add a place"; T-0072 (the wardrobe).

## Specification (as built)
**Changed from the draft:** the rail and the chair stand in **Waschsalon Blitz** (open 7–22,
shut on Sundays) instead of splitting Haus 3's ground floor. Taking that flat away removed a
household: seed 3 then lacked people for always-filled jobs, several tests depended on the
town's size, and old saves would have made a household homeless. The Waschsalon is a big empty
room with the right hours, so nobody loses their home.
- Objects `clothes_rack` (2×1, two slots) ×2 at (32,10) and (32,12), `barber_chair` at (39,11).
  Interactions `browse_clothes` (5 min, opens the "clothes_shop" screen) and `get_haircut`
  (€18 paid at the start, 30 min, moodlet `fresh_cut`, opens the "barber" screen).
- `Shopping` (`sim/people/shopping.gd`): `at_open`, `buy_clothes` (at a rail in an open lot,
  a catalog item and colour, not owned, `Money.spend` "purchase" → wardrobe), `change_hair`
  (at the chair, catalog style and colour). `BuyClothesCommand` (`buy_clothes`) and
  `ChangeHairCommand` (`change_hair`) with refusal events.
- `ShopScreen` (game): the rail lists every item with price, colour and Buy; the barber steps
  through styles and colours, then Done. Pauses the game; Esc closes. HUD notices.
- Save v17: old saves get the rail and chair; fixture.

## Acceptance criteria
- [x] Buying adds to the wardrobe and costs the price; you can't buy what you can't afford or
  already own → `test_buying_clothes`.
- [x] A haircut changes your hair and costs €18 → `test_a_haircut_costs_18_and_changes_your_hair`.
- [x] Both respect the hours → `test_the_shop_keeps_its_hours`; placed and reachable →
  `test_the_rail_and_chair_are_in_the_waschsalon`; old saves → `test_old_saves_get_the_rail_and_chair`.
- [ ] Screenshots of both screens: on the Mac.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (3 October 2026). Residents don't shop for
clothes yet (no free will for it). `test_save_validation`'s "wrong value" 17 became -17,
because 17 is now a real save version.

## Questions

## Review feedback
