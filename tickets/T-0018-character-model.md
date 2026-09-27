---
id: T-0018
title: Identity, appearance and outfit on every person; CharacterSpec; save v2
status: review
milestone: M1
size: L
owner: builder
depends_on: [T-0017]
builder: OpenCode / Muse Spark 1.3 Free
review_rounds: 0
---

## Goal
Every person has a name, nickname, gender, pronouns, age (18+), appearance and outfit, saved
with the game. A `CharacterSpec` describes a character before the game starts (it's what the
creator will fill in), validates it, can make a random one, and creates the player from it.
Old saves are upgraded by the **first save migration** (v1 → v2).

## Read first
- `docs/design/character-and-appearance.md`, `docs/design/people.md` → "Identity"
- T-0017's catalog classes and data (merged in `main`)
  (as merged: `content.appearance: AppearanceCatalog`, `content.clothing` and
  `content.clothing_def(id)` (null if unknown), `content.clothing_colours`,
  `content.first_names[list_id]`, `content.last_names`, `ClothingDef.SLOTS` /
  `REQUIRED_SLOTS`, `Names.is_valid(text, max_length)` and `Names.MAX_LENGTH`.
  `ContentDB.load_from()` now loads terrain, needs, names, appearance, clothing, then world;
  load and validate `default_player` after the world.)
- `docs/cookbook.md` → "Add a field to Person", **"Change the save format"** (you do it for
  real here)
- Code: `sim/people/person.gd`, `sim/sim_factory.gd`, `sim/save/save_codec.gd`,
  `sim/save/save_migrations.gd`, `tools/make_fixture_save.gd`

## Scope
Create: `sim/people/appearance.gd`, `sim/people/worn_item.gd`, `sim/people/outfit.gd`,
`sim/people/character_spec.gd`, `data/appearance/default_player.json`,
`tests/sim/test_character.gd`, `tests/sim/test_content_rules.gd`,
`tests/fixtures/saves/v2_basic.json` (via the tool).
Change: `sim/people/person.gd`, `sim/sim_factory.gd`, `sim/content/content_db.gd`
(default player), `sim/save/save_codec.gd` (version 2), `sim/save/save_migrations.gd`,
`game/session.gd` (`new_game` signature), `game/ui/debug_overlay.gd` (show display name and
age).
**Out of scope:** drawing appearance (T-0019), menus and creator UI (T-0020/T-0021),
personality, background and attraction (later milestones).

## Specification

### Appearance, WornItem, Outfit (`extends RefCounted`)
```gdscript
class_name Appearance
var skin_tone: String = ""
var height_cm: int = 175
var build: String = ""
var hair_style: String = ""
var hair_colour: String = ""
var eye_colour: String = ""
var facial_hair: String = "none"
var features: PackedStringArray = []
func validate(content: ContentDB) -> PackedStringArray   # one message per problem, e.g. "unknown skin tone 'x'", "height 140 cm is outside 150–205"
func copy() -> Appearance
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> Appearance
static func random(content: ContentDB, rng: RandomNumberGenerator) -> Appearance

class_name WornItem
var clothing_id: String = ""
var colour: String = ""

class_name Outfit
var items: Dictionary[String, WornItem] = {}              # slot -> item
func get_item(slot: String) -> WornItem                   # null if nothing worn there
func put_on(slot: String, clothing_id: String, colour: String) -> void
func take_off(slot: String) -> void
func validate(content: ContentDB) -> PackedStringArray    # unknown slot/item, item in the wrong slot, colour not allowed, a REQUIRED slot empty
func copy() -> Outfit
func to_dict() -> Dictionary                              # {"top": {"item": "t_shirt", "colour": "black"}, ...}
static func from_dict(d: Dictionary) -> Outfit
static func random(content: ContentDB, rng: RandomNumberGenerator, starter_only: bool = true) -> Outfit
```
**Random rules** (deterministic: always draw from `rng` in this order):
- Appearance: skin, build, hair style and eye colour uniform over the catalog;
  `height = (randi_range(min, max) + randi_range(min, max)) / 2`; hair colour natural with
  probability 0.85 (uniform among natural), else dyed; facial hair `none` with probability
  0.6, else uniform among the others; each feature with probability 0.15 (catalog order).
- Outfit: for each slot in `ClothingDef.SLOTS` order: required slots always, optional slots
  with probability 0.35; the item is uniform among eligible items for that slot (file order),
  and the colour is uniform among the item's colours.

### CharacterSpec
```gdscript
class_name CharacterSpec
var first_name: String = ""
var last_name: String = ""
var nickname: String = ""
var gender: String = ""
var pronouns: String = ""
var age_years: int = 18
var appearance: Appearance = Appearance.new()
var outfit: Outfit = Outfit.new()
func validate(content: ContentDB) -> PackedStringArray
static func default_player(content: ContentDB) -> CharacterSpec   # from content.default_player
static func random(content: ContentDB, rng: RandomNumberGenerator) -> CharacterSpec
func apply_to(person: Person) -> void                             # copies everything (appearance/outfit via copy())
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> CharacterSpec
```
- `validate`: first and last name `Names.is_valid(x, 24)`; nickname empty or
  `Names.is_valid(x, 16)`; gender and pronouns exist; **age ≥ 18 always** (checked in code
  even if data were wrong) and inside the catalog's age range; plus
  `appearance.validate()` and `outfit.validate()`.
- `random`: gender uniform; pronouns = the gender's `default_pronouns` with probability 0.9,
  else uniform; first name from one of the gender's `name_lists` (list uniform, then name
  uniform); last name uniform; nickname ""; age uniform in the catalog range; then
  `Appearance.random`, `Outfit.random`.
- `data/appearance/default_player.json` (the `to_dict()` shape), loaded by ContentDB into
  `var default_player: Dictionary` and validated at the end of `load_from()` through
  `CharacterSpec.from_dict(...).validate(self)`:
  Alex Novak, no nickname, nonbinary / they, 27, skin_04, 174 cm, average, short, dark_brown,
  hazel, facial hair none, no features; outfit: top `t_shirt` black, bottom `jeans` denim,
  feet `trainers` white, outer `hoodie` grey.

### Person
Add `nickname`, `gender`, `pronouns`, `age_years`, `appearance: Appearance`,
`outfit: Outfit`, and `func display_name() -> String` (nickname if set, else first name).
Save all of them in `to_dict()` / `from_dict()` (keys: `nickname`, `gender`, `pronouns`,
`age_years`, `appearance`, `outfit`).

### SimFactory and Session
- `SimFactory.new_game(content, seed_value, spec: CharacterSpec = null)`: null → the
  default player. The spec is assumed valid (the creator validates it).
  `_spawn_player(sim, cell, spec)` uses `spec.apply_to(person)` and keeps setting every
  need to its `start` value (T-0005). `from_rows` uses the
  default player. Remove the `PLAYER_FIRST_NAME` / `PLAYER_LAST_NAME` constants.
- `Session.new_game(seed_value: int, spec: CharacterSpec = null)` passes the spec through.

### Save version 2 (the first real migration)
- `SaveCodec.SAVE_VERSION = 2`.
- `SaveMigrations._v1_to_v2(d)`: every person in `d["world"]["people"]` gets the default
  player's identity, appearance and outfit written as **literal constants inside the
  migration** (migrations are frozen history; never read content from them), with the same
  values as `default_player.json` today. Add it to `migrate()`'s `match`.
- Run `tools/make_fixture_save.sh v2_basic` and commit `tests/fixtures/saves/v2_basic.json`.
  Keep `v1_basic.json` untouched.

## Acceptance criteria
`tests/sim/test_character.gd`:
- [ ] The default player spec is valid; a new game's player has its names, pronouns, age,
  appearance and outfit.
- [ ] `new_game` with a custom spec produces a player with exactly those values.
- [ ] 200 random specs (seeds 1–200) are all valid; the same seed gives an identical spec
  (compare `to_dict()` JSON).
- [ ] `validate` rejects, each with a message: age 17, empty first name, a name with digits,
  a 25-letter name, unknown skin tone / hair colour / hair style, a clothing item in the
  wrong slot, a colour the item doesn't allow, a missing top / bottom / feet.
- [ ] `apply_to` deep-copies: changing the spec's outfit afterwards doesn't change the person.
- [ ] Identity, appearance and outfit survive save/load, and "save mid-run equals
  uninterrupted run" still passes.
- [ ] The **v1 fixture** loads through the migration, and the player has a valid appearance
  and outfit (`validate` returns no errors); `v2_basic.json` loads too.

`tests/sim/test_content_rules.gd`:
- [ ] Every person in a new game is 18 or older.
- [ ] 200 random characters are all 18 or older.

- [ ] `tools/check.sh` passes.

## Implementation notes
Implemented on branch `t/0018-character-model`.
- New: `sim/people/appearance.gd`, `worn_item.gd`, `outfit.gd`, `character_spec.gd`
  (all `RefCounted`, typed, `validate`/`copy`/`to_dict`/`from_dict`/`random` with the
  deterministic draw orders from the spec; `random` takes a caller-supplied
  `RandomNumberGenerator` so sim purity holds).
- New: `data/appearance/default_player.json` (Alex Novak, nonbinary/they, 27, exactly the
  values in the spec).
- Changed: `Person` (+ nickname/gender/pronouns/age_years/appearance/outfit,
  `display_name()`, saved under the specified keys); `SimFactory.new_game(content, seed,
  spec=null)` / `_spawn_player(sim, cell, spec)` via `apply_to`, `from_rows` uses the
  default player, `PLAYER_*` constants removed; `ContentDB.default_player: Dictionary`
  loaded after the world and validated via `CharacterSpec.from_dict(...).validate(self)`
  with the path prefixed; `SAVE_VERSION = 2` with `_v1_to_v2` writing the default
  player's values as literals; `Session.new_game(seed, spec=null)`; debug overlay shows
  `display_name()` + age.
- One deviation from the spec text: `ContentDB.default_player` is a `Dictionary`
  (as the spec's ContentDB line says), so `CharacterSpec.default_player(content)` parses
  it with `from_dict` on each call.
- Verified: `tools/check.sh` → 81 passed, 0 failed (includes the 200-seed random-spec
  validity/determinism tests, all listed `validate` rejections, deep-copy, save/load
  round-trip, v1-fixture migration → valid appearance/outfit, v2 fixture loads).
  Fixture generated with `tools/make_fixture_save.sh v2_basic`; `v1_basic.json`
  untouched.
- Screenshot: no visible change (data/systems only; drawing is T-0019), so none taken.

## Questions

## Review feedback
