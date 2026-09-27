class_name AppearanceLoader
extends RefCounted
## Loads the character-creator catalog from data/appearance/appearance.json into
## a ContentDB (moved out of ContentDB so each content domain lives in a small
## file). ClothingLoader reuses `load_color_options` for clothing colours.


## Read `path` and fill `db.appearance` (validating name lists from NamesLoader).
static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root

	var age_ctx := "%s: age_years" % path
	var age: Dictionary = reader.read_obj(d, "age_years", path)
	db.appearance.age_min = int(reader.read_num(age, "min", age_ctx))
	db.appearance.age_max = int(reader.read_num(age, "max", age_ctx))
	if db.appearance.age_min < 18:
		reader.error("%s: min is %d, but everyone in the game is an adult (at least 18)" % [age_ctx, db.appearance.age_min])
	if db.appearance.age_max < db.appearance.age_min:
		reader.error("%s: max %d is below min %d" % [age_ctx, db.appearance.age_max, db.appearance.age_min])
	if db.appearance.age_max > 100:
		reader.error("%s: max %d is above 100" % [age_ctx, db.appearance.age_max])

	var height_ctx := "%s: height_cm" % path
	var height: Dictionary = reader.read_obj(d, "height_cm", path)
	db.appearance.height_min = int(reader.read_num(height, "min", height_ctx))
	db.appearance.height_max = int(reader.read_num(height, "max", height_ctx))
	if db.appearance.height_min < 120 or db.appearance.height_min >= db.appearance.height_max or db.appearance.height_max > 230:
		reader.error("%s: must satisfy 120 <= min < max <= 230, got %d..%d" % [height_ctx, db.appearance.height_min, db.appearance.height_max])

	db.appearance.genders = load_genders(reader, d.get("genders"), "%s: genders" % path)
	db.appearance.pronouns = load_pronouns(reader, d.get("pronouns"), "%s: pronouns" % path)
	db.appearance.skin_tones = load_color_options(reader, d.get("skin_tones"), "%s: skin_tones" % path)
	db.appearance.hair_colours = load_color_options(reader, d.get("hair_colours"), "%s: hair_colours" % path)
	db.appearance.eye_colours = load_color_options(reader, d.get("eye_colours"), "%s: eye_colours" % path)
	db.appearance.hair_styles = load_named_options(reader, d.get("hair_styles"), "%s: hair_styles" % path)
	db.appearance.builds = load_named_options(reader, d.get("builds"), "%s: builds" % path)
	db.appearance.facial_hair = load_named_options(reader, d.get("facial_hair"), "%s: facial_hair" % path)
	db.appearance.features = load_named_options(reader, d.get("features"), "%s: features" % path)

	if not db.appearance.facial_hair.has("none"):
		reader.error("%s: facial_hair must contain 'none'" % path)
	for gender: GenderOption in db.appearance.genders.values():
		if not db.appearance.pronouns.has(gender.default_pronouns):
			reader.error("%s: gender '%s' uses unknown pronouns '%s'" % [path, gender.id, gender.default_pronouns])
		for list_id: String in gender.name_lists:
			if not db.first_names.has(list_id):
				reader.error("%s: gender '%s' uses unknown name list '%s'" % [path, gender.id, list_id])


## Read the default player (data/appearance/default_player.json, CharacterSpec.to_dict()
## shape) into `db.default_player` and validate it with CharacterSpec. Runs last, after
## everything a character refers to (names, appearance, clothing) is loaded.
static func load_default_player(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	db.default_player = root
	for problem: String in CharacterSpec.from_dict(root).validate(db):
		reader.error("%s: %s" % [path, problem])


## Gender options keyed by id.
static func load_genders(reader: ContentReader, entries: Variant, ctx: String) -> Dictionary[String, GenderOption]:
	var out: Dictionary[String, GenderOption] = {}
	if not entries is Array:
		reader.error("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			reader.error("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var gender := GenderOption.new()
		gender.id = reader.read_str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, gender.id]
		gender.name = reader.read_str(d, "name", entry_ctx)
		gender.default_pronouns = reader.read_str(d, "default_pronouns", entry_ctx)
		gender.name_lists = reader.read_str_array(d, "name_lists", entry_ctx)
		if gender.id.is_empty():
			reader.error("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(gender.id):
			reader.error("%s: duplicate id" % entry_ctx)
			continue
		out[gender.id] = gender
	if out.is_empty():
		reader.error("%s must not be empty" % ctx)
	return out


## Pronoun sets keyed by id.
static func load_pronouns(reader: ContentReader, entries: Variant, ctx: String) -> Dictionary[String, PronounSet]:
	var out: Dictionary[String, PronounSet] = {}
	if not entries is Array:
		reader.error("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			reader.error("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var pronouns := PronounSet.new()
		pronouns.id = reader.read_str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, pronouns.id]
		pronouns.name = reader.read_str(d, "name", entry_ctx)
		pronouns.subject = reader.read_str(d, "subject", entry_ctx)
		pronouns.object = reader.read_str(d, "object", entry_ctx)
		pronouns.possessive = reader.read_str(d, "possessive", entry_ctx)
		pronouns.reflexive = reader.read_str(d, "reflexive", entry_ctx)
		if pronouns.id.is_empty():
			reader.error("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(pronouns.id):
			reader.error("%s: duplicate id" % entry_ctx)
			continue
		out[pronouns.id] = pronouns
	if out.is_empty():
		reader.error("%s must not be empty" % ctx)
	return out


## Id/name options keyed by id (hair styles, builds, facial hair, features).
static func load_named_options(reader: ContentReader, entries: Variant, ctx: String) -> Dictionary[String, NamedOption]:
	var out: Dictionary[String, NamedOption] = {}
	if not entries is Array:
		reader.error("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			reader.error("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var option := NamedOption.new()
		option.id = reader.read_str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, option.id]
		option.name = reader.read_str(d, "name", entry_ctx)
		if option.id.is_empty():
			reader.error("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(option.id):
			reader.error("%s: duplicate id" % entry_ctx)
			continue
		out[option.id] = option
	if out.is_empty():
		reader.error("%s must not be empty" % ctx)
	return out


## Coloured options keyed by id (skin tones, hair/eye colours, clothing colours).
static func load_color_options(reader: ContentReader, entries: Variant, ctx: String) -> Dictionary[String, ColorOption]:
	var out: Dictionary[String, ColorOption] = {}
	if not entries is Array:
		reader.error("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			reader.error("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var option := ColorOption.new()
		option.id = reader.read_str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, option.id]
		option.name = reader.read_str(d, "name", entry_ctx)
		var color_text := reader.read_str(d, "color", entry_ctx)
		if Color.html_is_valid(color_text):
			option.color = Color.html(color_text)
		else:
			reader.error("%s: color '%s' is not a colour like #aabbcc" % [entry_ctx, color_text])
		if d.has("natural"):
			option.natural = reader.read_bool(d, "natural", entry_ctx)
		if option.id.is_empty():
			reader.error("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(option.id):
			reader.error("%s: duplicate id" % entry_ctx)
			continue
		out[option.id] = option
	if out.is_empty():
		reader.error("%s must not be empty" % ctx)
	return out
