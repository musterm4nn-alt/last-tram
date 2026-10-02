---
id: T-0072
title: The wardrobe - owned clothes and saved outfits
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0055]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Clothes become things you own. Everyone has a wardrobe of clothes (starting with their outfit
and a few starter pieces) and saved outfits ("Everyday", "Work", "Going out"). A wardrobe at
home lets you change clothes or put on a saved outfit.

## Read first
`docs/design/character-and-appearance.md` → Clothes and outfits; `sim/people/outfit.gd`,
`game/ui/creator_clothes_tab.gd`.

## Specification (as built)
- `Person.wardrobe` (owned `WornItem`s, sorted) and `Person.outfits` (name → `Outfit`;
  names `Wardrobe.OUTFIT_NAMES`: Everyday, Work, Going out). Save v16: owned = what they wear,
  saved as "Everyday", and old towns get the wardrobes (`V16_WARDROBES`); fixture.
- `Wardrobe`: `owns`, `add`, `problems` (Outfit.validate + ownership), `at_wardrobe`,
  `give_start` / `give_person_start` (what they wear + 3 random starter pieces, stream
  "wardrobe"; new towns and newcomers).
- A `wardrobe` object in all 16 homes (spots found by a script: against a wall, the slot free,
  nothing in the flat cut off); "Change clothes" (2 min) with the new
  `InteractionDef.opens_screen` → `&"screen_requested" {person_id, screen: "wardrobe"}`
  (player only).
- `ChangeOutfitCommand(person_id, outfit, save_as)` (type `change_outfit`): at your
  wardrobe, owned pieces, top/bottom/feet worn, a known name; `&"outfit_changed"` /
  `&"outfit_refused"`.
- `WardrobeScreen` (game): the creator's clothes rows on a `CreatorModel` with `only_owned`,
  pick a saved outfit, "Save as …", "Put it on", "Close"; pauses the game while open.
- Free will now skips objects with nothing it could choose (`ContentDB.free_will_objects`),
  so the new furniture costs no pathfinding.

## Acceptance criteria
- [x] You can wear only what you own → `test_you_can_only_wear_what_you_own_at_your_wardrobe`,
  `test_wardrobe_model_offers_only_owned_clothes` (tests/game).
- [x] Saved outfits round-trip; old saves migrate → `test_wardrobes_survive_saves_and_old_saves_migrate`.
- [x] The command validates; the wardrobe opens the screen; every home has a reachable
  wardrobe → the tests in `tests/sim/test_wardrobe.gd`.
- [ ] Screenshot of the wardrobe screen: on the Mac.

## Implementation notes
Built and self-reviewed by Opus in a cloud session (2 October 2026). Residents don't change
for work yet (the ticket called it optional). `--check-m2` passes on seeds 1–6 in both modes
for the town's life; the cost check is at the edge on this cloud machine (0.252 ms per step
alone, about 2.5× slower than the Mac), which is T-0078's job.

## Questions

## Review feedback
