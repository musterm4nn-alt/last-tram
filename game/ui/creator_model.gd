class_name CreatorModel
extends RefCounted
## The character being made in the character creator, with the creator's rules: step
## through each option list, age and height within limits, features, a starter outfit with
## colours, and randomising one section or everything. Pure: no nodes (the screens are
## CharacterCreator and friends).

const AGE_MIN: int = Person.MIN_AGE
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

var _content: ContentDB


## Starts from the default player's look with EMPTY names (the player names their
## character), or from a copy of `start` when given.
func _init(p_content: ContentDB, start: CharacterSpec = null) -> void:
	_content = p_content
	if start != null:
		spec = CharacterSpec.from_dict(start.to_dict())
	else:
		spec = CharacterSpec.default_player(p_content)
		spec.first_name = ""
		spec.last_name = ""
		spec.nickname = ""


## Option ids for a list field, in catalog (file) order.
func options(field: String) -> PackedStringArray:
	var catalog: AppearanceCatalog = _content.appearance
	var source: Dictionary = {}
	match field:
		"gender":
			source = catalog.genders
		"pronouns":
			source = catalog.pronouns
		"skin_tone":
			source = catalog.skin_tones
		"build":
			source = catalog.builds
		"hair_style":
			source = catalog.hair_styles
		"hair_colour":
			source = catalog.hair_colours
		"eye_colour":
			source = catalog.eye_colours
		"facial_hair":
			source = catalog.facial_hair
	return PackedStringArray(source.keys())


## The name to show for an option of a list field ("Short", "Dark brown"...), or the id
## itself when the catalog has no such option.
func option_name(field: String, id: String) -> String:
	var catalog: AppearanceCatalog = _content.appearance
	var option: Variant = null
	match field:
		"gender":
			option = catalog.genders.get(id)
		"pronouns":
			option = catalog.pronouns.get(id)
		"skin_tone":
			option = catalog.skin_tones.get(id)
		"build":
			option = catalog.builds.get(id)
		"hair_style":
			option = catalog.hair_styles.get(id)
		"hair_colour":
			option = catalog.hair_colours.get(id)
		"eye_colour":
			option = catalog.eye_colours.get(id)
		"facial_hair":
			option = catalog.facial_hair.get(id)
	if option == null:
		return id
	return String(option.get("name"))


## The current id of a list field.
func value(field: String) -> String:
	match field:
		"gender":
			return spec.gender
		"pronouns":
			return spec.pronouns
	return String(spec.appearance.get(field))


## Next option of a list field, wrapping around at the end. Setting gender does not change
## pronouns (they are chosen independently).
func next(field: String) -> void:
	_step(field, 1)


## Previous option of a list field, wrapping around at the start.
func previous(field: String) -> void:
	_step(field, -1)


## Age, clamped to AGE_MIN..AGE_MAX (never below 18).
func set_age(years: int) -> void:
	spec.age_years = clampi(years, AGE_MIN, AGE_MAX)


## Height in cm, clamped to HEIGHT_MIN..HEIGHT_MAX.
func set_height(cm: int) -> void:
	spec.appearance.height_cm = clampi(cm, HEIGHT_MIN, HEIGHT_MAX)


## Feature ids in catalog order.
func feature_options() -> PackedStringArray:
	return PackedStringArray(_content.appearance.features.keys())


## Turns a feature on or off; the list stays in catalog order.
func toggle_feature(id: String) -> void:
	var chosen := spec.appearance.features
	var wanted := PackedStringArray()
	for option: String in feature_options():
		var on := chosen.has(option)
		if option == id:
			on = not on
		if on:
			wanted.append(option)
	spec.appearance.features = wanted


## Starter items for a slot in file order. Optional slots start with "" (wear nothing);
## required slots (ClothingDef.REQUIRED_SLOTS) never offer "".
func clothing_options(slot: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not ClothingDef.REQUIRED_SLOTS.has(slot):
		out.append("")
	for item: ClothingDef in _content.clothing.values():
		if item.slot == slot and item.starter:
			out.append(item.id)
	return out


## The item worn in a slot, or "".
func clothing(slot: String) -> String:
	var worn := spec.outfit.get_item(slot)
	return worn.clothing_id if worn != null else ""


## Next item for a slot (wrapping); a newly chosen item gets its first colour.
func next_clothing(slot: String) -> void:
	_step_clothing(slot, 1)


## Previous item for a slot (wrapping).
func previous_clothing(slot: String) -> void:
	_step_clothing(slot, -1)


## Colours of the item worn in `slot` ([] when nothing is worn).
func colour_options(slot: String) -> PackedStringArray:
	var def := _content.clothing_def(clothing(slot))
	return def.colours if def != null else PackedStringArray()


## Chooses a colour for the item worn in `slot` (ignored when it does not come in it).
func set_colour(slot: String, colour: String) -> void:
	if colour_options(slot).has(colour):
		spec.outfit.put_on(slot, clothing(slot), colour)


## Randomises one section; every field of the other sections stays exactly as it was.
## Draws only from `rng`. Age and height are clamped to the creator's limits.
func randomise(section: String, rng: RandomNumberGenerator) -> void:
	match section:
		"name":
			_random_name(rng)
		"identity":
			var drawn := CharacterSpec.random(_content, rng)
			spec.gender = drawn.gender
			spec.pronouns = drawn.pronouns
			set_age(drawn.age_years)
		"body":
			var look := Appearance.random(_content, rng)
			set_height(look.height_cm)
			spec.appearance.build = look.build
			spec.appearance.skin_tone = look.skin_tone
		"face":
			var look := Appearance.random(_content, rng)
			spec.appearance.hair_style = look.hair_style
			spec.appearance.hair_colour = look.hair_colour
			spec.appearance.eye_colour = look.eye_colour
			spec.appearance.facial_hair = look.facial_hair
			spec.appearance.features = look.features
		"clothes":
			spec.outfit = Outfit.random(_content, rng, true)


## Every section, in SECTIONS order.
func randomise_all(rng: RandomNumberGenerator) -> void:
	for section: String in SECTIONS:
		randomise(section, rng)


## Problems that keep Start disabled (empty when the character is ready).
func errors() -> PackedStringArray:
	return spec.validate(_content)


func _step(field: String, direction: int) -> void:
	var ids := options(field)
	if ids.is_empty():
		return
	var chosen := ids[_stepped(ids.find(value(field)), direction, ids.size())]
	match field:
		"gender":
			spec.gender = chosen
		"pronouns":
			spec.pronouns = chosen
		_:
			spec.appearance.set(field, chosen)


func _step_clothing(slot: String, direction: int) -> void:
	var ids := clothing_options(slot)
	if ids.is_empty():
		return
	var chosen := ids[_stepped(ids.find(clothing(slot)), direction, ids.size())]
	if chosen.is_empty():
		spec.outfit.take_off(slot)
		return
	var def := _content.clothing_def(chosen)
	spec.outfit.put_on(slot, chosen, def.colours[0] if def != null and not def.colours.is_empty() else "")


## The index one step from `at` in a list of `count` (wrapping). From an unknown value
## (at < 0), next goes to the first option and previous to the last.
static func _stepped(at: int, direction: int, count: int) -> int:
	if at < 0:
		return 0 if direction > 0 else count - 1
	return posmod(at + direction, count)


## First and last name from one of the current gender's name lists; no nickname.
func _random_name(rng: RandomNumberGenerator) -> void:
	var gender: GenderOption = _content.appearance.genders.get(spec.gender)
	if gender == null or gender.name_lists.is_empty():
		var drawn := CharacterSpec.random(_content, rng)
		spec.first_name = drawn.first_name
		spec.last_name = drawn.last_name
	else:
		var list_id := String(gender.name_lists[rng.randi_range(0, gender.name_lists.size() - 1)])
		var firsts: PackedStringArray = _content.first_names[list_id]
		spec.first_name = firsts[rng.randi_range(0, firsts.size() - 1)]
		spec.last_name = _content.last_names[rng.randi_range(0, _content.last_names.size() - 1)]
	spec.nickname = ""
