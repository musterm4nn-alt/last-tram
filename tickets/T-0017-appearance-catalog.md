---
id: T-0017
title: Appearance, clothing and name catalogs (content + validation)
status: todo
milestone: M1
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
The game knows every choice the character creator will offer: genders and pronouns, skin
tones, hair styles and colours, eye colours, builds, facial hair, features, clothing items and
colours, and name lists. All of it is loaded from data and validated. Nothing uses it yet:
T-0018 puts it on people.

## Read first
- `docs/design/character-and-appearance.md` (whole file; especially "Rules": everyone is an
  adult)
- `AGENTS.md` → content rules; `docs/cookbook.md` → "Add a new kind of content"
- Pattern to copy: `sim/content/content_db.gd` (`_load_terrains`, the `_str/_num/_bool/_arr`
  readers) and `sim/content/terrain_def.gd`

## Scope
Create:
- `data/appearance/appearance.json`, `data/clothing/colours.json`,
  `data/clothing/items/starter.json`, `data/names/names.json`
- `sim/content/color_option.gd`, `sim/content/named_option.gd`,
  `sim/content/gender_option.gd`, `sim/content/pronoun_set.gd`,
  `sim/content/appearance_catalog.gd`, `sim/content/clothing_def.gd`
- `sim/people/names.gd`
- `tests/sim/test_appearance_content.gd`, plus broken examples in
  `tests/fixtures/content_broken/` (new files next to the existing ones)

Change: `sim/content/content_db.gd` (load and validate all of the above).
**Out of scope:** anything on `Person`, saving, the creator UI, drawing.

## Specification

### Classes (all `extends RefCounted`, typed fields, `##` docs)
```gdscript
class_name NamedOption      # id, name
class_name ColorOption      # id, name, color: Color, natural: bool = true (only used for hair)
class_name GenderOption     # id, name, default_pronouns: String, name_lists: PackedStringArray
class_name PronounSet       # id, name, subject, object, possessive, reflexive
class_name ClothingDef
const SLOTS: PackedStringArray = ["head", "face", "neck", "top", "outer", "bottom", "feet", "hands", "bag"]
const REQUIRED_SLOTS: PackedStringArray = ["top", "bottom", "feet"]
var id: String; var name: String; var slot: String
var styles: PackedStringArray       # "casual", "formal", "sporty", "street", "workwear"
var colours: PackedStringArray      # ids from data/clothing/colours.json
var price: int                      # euro cents
var formality: int                  # -2..3
var concealment: int                # 0..3
var warmth: int                     # 0..3
var starter: bool                   # offered in the character creator

class_name AppearanceCatalog
var age_min: int; var age_max: int; var height_min: int; var height_max: int
var genders: Dictionary[String, GenderOption]
var pronouns: Dictionary[String, PronounSet]
var skin_tones: Dictionary[String, ColorOption]
var hair_colours: Dictionary[String, ColorOption]
var eye_colours: Dictionary[String, ColorOption]
var hair_styles: Dictionary[String, NamedOption]
var builds: Dictionary[String, NamedOption]
var facial_hair: Dictionary[String, NamedOption]
var features: Dictionary[String, NamedOption]

class_name Names            # sim/people/names.gd, static helpers only
## Letters (any language, e.g. "Jürgen", "Łukasz"; combining accents allowed), spaces,
## hyphens and apostrophes; must start with a letter; 1..max_length characters.
## Use RegEx "^\\p{L}[\\p{L}\\p{M} '\\-]*$" plus a length check.
static func is_valid(text: String, max_length: int = 24) -> bool
```
Dictionaries keep the file order: the creator shows options in that order.

### ContentDB additions
```gdscript
var appearance: AppearanceCatalog
var clothing: Dictionary[String, ClothingDef]
var clothing_colours: Dictionary[String, ColorOption]
var first_names: Dictionary[String, PackedStringArray]   # "feminine", "masculine", "neutral"
var last_names: PackedStringArray
func clothing_def(id: String) -> ClothingDef             # null if unknown
```
Load order in `load_from()`: terrain, **names**, **appearance**, **clothing**, then world.
Load every `.json` in `data/clothing/items/` (sorted by file name).

### Data
`data/appearance/appearance.json` (every list non-empty; ids snake_case and unique per list):
```json
{
	"_doc": "...",
	"age_years": { "min": 18, "max": 80 },
	"height_cm": { "min": 150, "max": 205 },
	"genders": [
		{ "id": "woman", "name": "Woman", "default_pronouns": "she", "name_lists": ["feminine"] },
		{ "id": "man", "name": "Man", "default_pronouns": "he", "name_lists": ["masculine"] },
		{ "id": "nonbinary", "name": "Non-binary", "default_pronouns": "they", "name_lists": ["neutral", "feminine", "masculine"] }
	],
	"pronouns": [
		{ "id": "she", "name": "she/her", "subject": "she", "object": "her", "possessive": "her", "reflexive": "herself" },
		{ "id": "he", "name": "he/him", "subject": "he", "object": "him", "possessive": "his", "reflexive": "himself" },
		{ "id": "they", "name": "they/them", "subject": "they", "object": "them", "possessive": "their", "reflexive": "themself" }
	],
	"skin_tones": [ { "id": "skin_01", "name": "Porcelain", "color": "#f6e1d3" } ],
	"hair_colours": [ { "id": "black", "name": "Black", "color": "#1d1a18", "natural": true } ],
	"eye_colours": [ { "id": "brown", "name": "Brown", "color": "#5a3a22" } ],
	"hair_styles": [ { "id": "bald", "name": "Bald" } ],
	"builds": [ { "id": "slim", "name": "Slim" } ],
	"facial_hair": [ { "id": "none", "name": "None" } ],
	"features": [ { "id": "freckles", "name": "Freckles" } ]
}
```
Fill the lists with at least: **8 skin tones** with ids `skin_01` (lightest) to `skin_08`
(darkest), a realistic range; **hair colours**: 9 natural (black, dark_brown, brown, auburn, ginger, dark_blonde,
blonde, grey, white) and 6 dyed (`natural: false`: platinum, pink, blue, green, purple, red);
**6 eye colours** (dark_brown, brown, hazel, green, blue, grey); **hair styles**: bald, buzz,
short, side_part, undercut, curly_short, bob, shoulder, long, ponytail, bun, braids, afro,
dreadlocks, mohawk; **builds**: slim, average, athletic, stocky, heavy; **facial hair**:
none, stubble, moustache, goatee, short_beard, full_beard; **features**: freckles, glasses,
beauty_mark.

`data/clothing/colours.json`: `{"colours": [...]}` with at least 16 colours (black, white,
grey, charcoal, navy, denim, red, burgundy, olive, forest, mustard, beige, brown, pink,
purple, orange).

`data/clothing/items/starter.json`: `{"items": [...]}` using this shape:
```json
{ "id": "hoodie", "name": "Hoodie", "slot": "outer", "styles": ["casual", "street"],
  "colours": ["black", "grey", "navy", "olive", "burgundy"], "price": 3500,
  "formality": -1, "concealment": 1, "warmth": 2, "starter": true }
```
At least 22 starter items: head (beanie, cap), face (sunglasses), neck (scarf, chain), top
(t_shirt, shirt, blouse, sweater, tank_top), outer (hoodie, denim_jacket, leather_jacket,
parka, blazer), bottom (jeans, chinos, skirt, shorts, track_pants), feet (trainers, boots,
dress_shoes), hands (gloves), bag (backpack, tote_bag). No underwear slot, and nothing
sexualised. T-0018's default character wears these, so they **must** be allowed:
`t_shirt` in `black`, `jeans` in `denim`, `trainers` in `white`, `hoodie` in `grey`.

`data/names/names.json`: `{"first_names": {"feminine": [...], "masculine": [...],
"neutral": [...]}, "last_names": [...]}` with at least 30 / 30 / 12 first names and 50 last
names. Use a Central-European city mix: German, Turkish, Polish, Czech, Dutch, Italian,
Syrian, Balkan, Vietnamese.

### Validation (errors name the file, the entry and the problem)
- `age_years.min` **must be ≥ 18** (message contains "18": everyone in the game is an
  adult); `max ≥ min`; `max ≤ 100`. Height: 120 ≤ min < max ≤ 230.
- Every list present and non-empty, ids unique per list, colours valid, `facial_hair`
  contains `"none"`.
- Genders: `default_pronouns` exists in pronouns; every `name_lists` entry is a key of
  `first_names`.
- Clothing: `slot` in `ClothingDef.SLOTS`; `colours` non-empty and every colour exists;
  price ≥ 0; formality −2..3; concealment 0..3; warmth 0..3; ids unique across all item files;
  **every slot in `REQUIRED_SLOTS` has at least one `starter` item.**
- Names: every name passes `Names.is_valid()`; the three first-name lists and last names are
  non-empty.

## Acceptance criteria
- [ ] Real content loads with zero errors → existing `test_content.gd::test_game_content_is_valid`
- [ ] `test_appearance_content.gd`: minimum counts from this ticket hold; every required slot
  has a starter item; every gender's name lists exist; all item colours exist
- [ ] `Names.is_valid`: accepts "Jürgen", "Łukasz", "Anne-Marie", "O'Neill", "Nguyễn"; rejects
  "", " Anna", "R2D2", "Anna!", and a 25-letter name (max 24) → tests
- [ ] Broken fixtures are reported: age min 17 (message contains "18"), unknown clothing
  colour, invalid slot, duplicate id, a required slot with no starter item → tests
- [ ] `tools/check.sh` passes

## Implementation notes

## Questions

## Review feedback
