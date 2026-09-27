---
id: T-0021
title: Character creator model: every choice, limits and randomise (no UI yet)
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0020]
builder:
review_rounds: 0
---

## Goal
Everything the character creator lets you choose, as a small testable model: step through
each option list, set age and height within the creator's limits, toggle features, pick a
starter outfit with colours, and randomise one section or everything. The screens that use
it are T-0026 (sections and preview), T-0029 (clothes and randomise buttons) and T-0027
(portrait and gallery).

## Read first
- `docs/design/character-and-appearance.md` → "The character creator" (limits: age 18–80,
  height 150–205 cm)
- As merged: `sim/people/character_spec.gd` (`validate`, `default_player`, `random`),
  `sim/people/appearance.gd`, `sim/people/outfit.gd` (`put_on`, `take_off`, `get_item`),
  `sim/content/appearance_catalog.gd` (option dictionaries in file order),
  `sim/content/clothing_def.gd` (`SLOTS`, `REQUIRED_SLOTS`, `starter`, `colours`),
  `ContentDB.first_names` / `last_names`, `GenderOption.name_lists`
- `game/ui/name_screen.gd` (today's first step; T-0026 replaces it)

## Scope
Create `game/ui/creator_model.gd` (`CreatorModel`) and `tests/game/test_creator_model.gd`.
**Out of scope:** any UI or scene, changing `sim/` classes (use them as they are), new
content.

## Specification
```gdscript
class_name CreatorModel
extends RefCounted
## The character being made in the creator, with the creator's rules. Pure: no nodes.

const AGE_MIN: int = 18          # never below Person.MIN_AGE
const AGE_MAX: int = 80
const HEIGHT_MIN: int = 150
const HEIGHT_MAX: int = 205
## Section ids, in tab order.
const SECTIONS: PackedStringArray = ["name", "identity", "body", "face", "clothes"]
## Fields stepped with next()/previous(), and the section each belongs to.
const LIST_FIELDS: Dictionary = {
	"gender": "identity", "pronouns": "identity",
	"skin_tone": "body", "build": "body",
	"hair_style": "face", "hair_colour": "face", "eye_colour": "face", "facial_hair": "face",
}

var spec: CharacterSpec

## Starts from the default player's look with EMPTY names (the player names their character),
## or from a copy of `start` when given.
func _init(p_content: ContentDB, start: CharacterSpec = null) -> void

## Option ids for a list field, in catalog (file) order.
func options(field: String) -> PackedStringArray
## The current id of a list field.
func value(field: String) -> String
## Next / previous option of a list field, wrapping around at the ends. Setting gender does
## not change pronouns (they are chosen independently).
func next(field: String) -> void
func previous(field: String) -> void

## Clamped to AGE_MIN..AGE_MAX and HEIGHT_MIN..HEIGHT_MAX.
func set_age(years: int) -> void
func set_height(cm: int) -> void
## Feature ids in catalog order, and toggling one on or off (kept in catalog order).
func feature_options() -> PackedStringArray
func toggle_feature(id: String) -> void

## Starter items (ClothingDef.starter) for a slot in file order. Optional slots start with
## "" (wear nothing); required slots (ClothingDef.REQUIRED_SLOTS) never offer "".
func clothing_options(slot: String) -> PackedStringArray
## The item worn in a slot, or "".
func clothing(slot: String) -> String
## Next / previous item for a slot (wrapping); a newly chosen item gets its first colour.
func next_clothing(slot: String) -> void
func previous_clothing(slot: String) -> void
## Colours of the item worn in `slot` ([] when nothing is worn), and choosing one
## (ignored when the item does not come in that colour).
func colour_options(slot: String) -> PackedStringArray
func set_colour(slot: String, colour: String) -> void

## Randomises one section; every field of the other sections stays exactly as it was.
##   name: first and last name from one of the current gender's name lists (nickname "")
##   identity: gender, pronouns (the gender's default pronouns 90% of the time), age
##   body: height, build, skin tone      face: hair style and colour, eyes, facial hair, features
##   clothes: a new starter outfit (Outfit.random with starter_only)
## Draws only from `rng`. Age and height are clamped to the creator's limits.
func randomise(section: String, rng: RandomNumberGenerator) -> void
## Every section, in SECTIONS order.
func randomise_all(rng: RandomNumberGenerator) -> void

## spec.validate(content): empty when Start may be pressed.
func errors() -> PackedStringArray
```
Tip: for `randomise(section)`, build `CharacterSpec.random(content, rng)` (or
`Appearance.random` / `Outfit.random`) and copy only that section's fields, then clamp.

## Acceptance criteria (`tests/game/test_creator_model.gd`)
- [ ] A new model has empty first and last names, the default player's look, and
  `errors()` complains only about the names.
- [ ] For every list field: stepping `next()` `options(field).size()` times visits every
  option exactly once and returns to the start; `previous()` from the first option goes to
  the last.
- [ ] `set_age`: 17 → 18, 81 → 80, 40 → 40; `set_height`: 140 → 150, 210 → 205. Age can never
  be set below 18 by any call.
- [ ] `toggle_feature` adds and removes, and the list stays in catalog order.
- [ ] Clothes: required slots never offer ""; optional slots do; `next_clothing` on
  `"bottom"` cycles through every starter bottom; a new item takes its first colour;
  `set_colour` with a colour the item lacks changes nothing.
- [ ] `randomise("face", rng)` changes only face fields (compare `to_dict()` of the other
  sections' fields before and after, over 20 seeds); likewise for each of the five sections;
  randomised names come from the current gender's name lists.
- [ ] `randomise_all` with the same seed twice gives the same spec, and every
  `randomise_all` result has no `errors()` (over 100 seeds).
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
