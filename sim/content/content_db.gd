class_name ContentDB
extends RefCounted
## All game content from data/, loaded once at startup and validated. Read-only at runtime.
## Loading never crashes: problems are collected in `errors` (tests require it to be empty).
##
## To add a new kind of content (objects, interactions, jobs...):
##   1. a *Def class in sim/content/
##   2. a _load_<things>() function here, using the _str/_num/_bool/_arr readers
##   3. validation of every reference it makes (ids that must exist)
##   4. a test in tests/sim/test_content.gd

const DATA_ROOT: String = "res://data"
## Name lists every game must have (data/names/names.json).
const FIRST_NAME_LISTS: PackedStringArray = ["feminine", "masculine", "neutral"]

var terrains: Array[TerrainDef] = []
var needs: Array[NeedDef] = []
var districts: Dictionary[String, DistrictDef] = {}
## District ids in the order they are stamped into the world.
var district_order: Array[String] = []
var start_district: String = ""
var errors: PackedStringArray = []

## Every choice the character creator offers (genders, colours, hair, names...).
var appearance: AppearanceCatalog = AppearanceCatalog.new()
## Clothing items by id, loaded from every file in data/clothing/items/.
var clothing: Dictionary[String, ClothingDef] = {}
## Clothing colour options by id, from data/clothing/colours.json.
var clothing_colours: Dictionary[String, ColorOption] = {}
## First names per name list (see FIRST_NAME_LISTS).
var first_names: Dictionary[String, PackedStringArray] = {}
var last_names: PackedStringArray = PackedStringArray()

var _terrain_by_id: Dictionary[String, int] = {}
var _terrain_by_glyph: Dictionary[String, int] = {}
var _need_by_id: Dictionary[String, NeedDef] = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_from(DATA_ROOT)
	return db


func load_from(root: String) -> void:
	_load_terrains(root.path_join("terrain.json"))
	_load_needs(root.path_join("needs.json"))
	_load_names(root.path_join("names").path_join("names.json"))
	_load_appearance(root.path_join("appearance").path_join("appearance.json"))
	_load_clothing(root.path_join("clothing"))
	_load_world(root.path_join("world"))


func is_valid() -> bool:
	return errors.is_empty()


# --- Queries ---------------------------------------------------------------------------

## Index into `terrains`, or -1.
func terrain_index(terrain_id: String) -> int:
	return _terrain_by_id.get(terrain_id, -1)


## Index into `terrains` for an ASCII map glyph, or -1.
func terrain_index_for_glyph(glyph: String) -> int:
	return _terrain_by_glyph.get(glyph, -1)


func terrain(index: int) -> TerrainDef:
	return terrains[index]


## The NeedDef with the given id, or null.
func need(need_id: String) -> NeedDef:
	if _need_by_id.has(need_id):
		return _need_by_id[need_id]
	return null


## The place containing a world cell, or null.
func place_at(cell: Vector3i) -> PlaceDef:
	for district_id: String in district_order:
		for place: PlaceDef in districts[district_id].places:
			if place.contains(cell):
				return place
	return null


## The clothing item with this id, or null.
func clothing_def(id: String) -> ClothingDef:
	return clothing.get(id)


# --- Terrain ---------------------------------------------------------------------------

func _load_terrains(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in _arr(root, "terrains", path):
		if not entry is Dictionary:
			errors.append("%s: every terrain must be an object" % path)
			continue
		var d: Dictionary = entry
		var t := TerrainDef.new()
		t.id = _str(d, "id", path)
		var ctx := "%s: terrain '%s'" % [path, t.id]
		t.name = _str(d, "name", ctx)
		t.glyph = _str(d, "glyph", ctx)
		t.walkable = _bool(d, "walkable", ctx)
		t.blocks_sight = _bool(d, "blocks_sight", ctx)
		t.indoor = _bool(d, "indoor", ctx)
		t.surface = _str(d, "surface", ctx)
		var color_text := _str(d, "debug_color", ctx)
		if Color.html_is_valid(color_text):
			t.debug_color = Color.html(color_text)
		else:
			errors.append("%s: debug_color '%s' is not a colour like #aabbcc" % [ctx, color_text])
		if t.glyph.length() != 1:
			errors.append("%s: glyph must be exactly one character" % ctx)
		if _terrain_by_id.has(t.id):
			errors.append("%s: duplicate terrain id" % ctx)
		if _terrain_by_glyph.has(t.glyph):
			errors.append("%s: glyph '%s' already used by another terrain" % [ctx, t.glyph])
		_terrain_by_id[t.id] = terrains.size()
		_terrain_by_glyph[t.glyph] = terrains.size()
		terrains.append(t)
	if terrain_index("void") < 0:
		errors.append("%s: a terrain with id 'void' is required (used outside the map)" % path)


# --- Needs -----------------------------------------------------------------------------

func _load_needs(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in _arr(root, "needs", path):
		if not entry is Dictionary:
			errors.append("%s: every need must be an object" % path)
			continue
		var d: Dictionary = entry
		var n := NeedDef.new()
		n.id = _str(d, "id", path)
		var ctx := "%s: need '%s'" % [path, n.id]
		n.name = _str(d, "name", ctx)
		n.decay_per_hour = _num(d, "decay_per_hour", ctx)
		n.start = _num(d, "start", ctx)
		n.urgency_weight = _num(d, "urgency_weight", ctx)
		n.critical_below = _num(d, "critical_below", ctx)
		if n.id.is_empty():
			errors.append("%s: need id must not be empty" % path)
		if _need_by_id.has(n.id):
			errors.append("%s: duplicate need id" % ctx)
		if n.decay_per_hour < 0.0:
			errors.append("%s: 'decay_per_hour' must be >= 0" % ctx)
		if n.start < 0.0 or n.start > 100.0:
			errors.append("%s: 'start' must be within 0..100" % ctx)
		if n.critical_below < 0.0 or n.critical_below > 100.0:
			errors.append("%s: 'critical_below' must be within 0..100" % ctx)
		if n.urgency_weight <= 0.0:
			errors.append("%s: 'urgency_weight' must be > 0" % ctx)
		_need_by_id[n.id] = n
		needs.append(n)


# --- Names -----------------------------------------------------------------------------

func _load_names(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root
	var lists: Variant = d.get("first_names")
	if not lists is Dictionary:
		errors.append("%s: 'first_names' must be an object of name lists" % path)
	else:
		for key: Variant in lists:
			var list_id := String(key)
			first_names[list_id] = _name_list(lists[key], "%s: first_names '%s'" % [path, list_id])
		for list_id: String in FIRST_NAME_LISTS:
			if not first_names.has(list_id):
				errors.append("%s: first_names is missing the '%s' list" % [path, list_id])
	last_names = _name_list(d.get("last_names"), "%s: last_names" % path)


func _name_list(value: Variant, ctx: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not value is Array:
		errors.append("%s must be a list of names" % ctx)
		return names
	for entry: Variant in value:
		if not entry is String:
			errors.append("%s: every name must be a string" % ctx)
			continue
		var name := String(entry)
		if not Names.is_valid(name):
			errors.append("%s: '%s' is not a name (1..%d letters; spaces, hyphens and apostrophes allowed)" % [ctx, name, Names.MAX_LENGTH])
			continue
		names.append(name)
	if names.is_empty():
		errors.append("%s must not be empty" % ctx)
	return names


# --- Appearance ------------------------------------------------------------------------

func _load_appearance(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root

	var age_ctx := "%s: age_years" % path
	var age: Dictionary = _obj(d, "age_years", path)
	appearance.age_min = int(_num(age, "min", age_ctx))
	appearance.age_max = int(_num(age, "max", age_ctx))
	if appearance.age_min < 18:
		errors.append("%s: min is %d, but everyone in the game is an adult (at least 18)" % [age_ctx, appearance.age_min])
	if appearance.age_max < appearance.age_min:
		errors.append("%s: max %d is below min %d" % [age_ctx, appearance.age_max, appearance.age_min])
	if appearance.age_max > 100:
		errors.append("%s: max %d is above 100" % [age_ctx, appearance.age_max])

	var height_ctx := "%s: height_cm" % path
	var height: Dictionary = _obj(d, "height_cm", path)
	appearance.height_min = int(_num(height, "min", height_ctx))
	appearance.height_max = int(_num(height, "max", height_ctx))
	if appearance.height_min < 120 or appearance.height_min >= appearance.height_max or appearance.height_max > 230:
		errors.append("%s: must satisfy 120 <= min < max <= 230, got %d..%d" % [height_ctx, appearance.height_min, appearance.height_max])

	appearance.genders = _load_genders(d.get("genders"), "%s: genders" % path)
	appearance.pronouns = _load_pronouns(d.get("pronouns"), "%s: pronouns" % path)
	appearance.skin_tones = _load_color_options(d.get("skin_tones"), "%s: skin_tones" % path)
	appearance.hair_colours = _load_color_options(d.get("hair_colours"), "%s: hair_colours" % path)
	appearance.eye_colours = _load_color_options(d.get("eye_colours"), "%s: eye_colours" % path)
	appearance.hair_styles = _load_named_options(d.get("hair_styles"), "%s: hair_styles" % path)
	appearance.builds = _load_named_options(d.get("builds"), "%s: builds" % path)
	appearance.facial_hair = _load_named_options(d.get("facial_hair"), "%s: facial_hair" % path)
	appearance.features = _load_named_options(d.get("features"), "%s: features" % path)

	if not appearance.facial_hair.has("none"):
		errors.append("%s: facial_hair must contain 'none'" % path)
	for gender: GenderOption in appearance.genders.values():
		if not appearance.pronouns.has(gender.default_pronouns):
			errors.append("%s: gender '%s' uses unknown pronouns '%s'" % [path, gender.id, gender.default_pronouns])
		for list_id: String in gender.name_lists:
			if not first_names.has(list_id):
				errors.append("%s: gender '%s' uses unknown name list '%s'" % [path, gender.id, list_id])


func _load_genders(entries: Variant, ctx: String) -> Dictionary[String, GenderOption]:
	var out: Dictionary[String, GenderOption] = {}
	if not entries is Array:
		errors.append("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			errors.append("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var gender := GenderOption.new()
		gender.id = _str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, gender.id]
		gender.name = _str(d, "name", entry_ctx)
		gender.default_pronouns = _str(d, "default_pronouns", entry_ctx)
		gender.name_lists = _str_array(d, "name_lists", entry_ctx)
		if gender.id.is_empty():
			errors.append("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(gender.id):
			errors.append("%s: duplicate id" % entry_ctx)
			continue
		out[gender.id] = gender
	if out.is_empty():
		errors.append("%s must not be empty" % ctx)
	return out


func _load_pronouns(entries: Variant, ctx: String) -> Dictionary[String, PronounSet]:
	var out: Dictionary[String, PronounSet] = {}
	if not entries is Array:
		errors.append("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			errors.append("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var pronouns := PronounSet.new()
		pronouns.id = _str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, pronouns.id]
		pronouns.name = _str(d, "name", entry_ctx)
		pronouns.subject = _str(d, "subject", entry_ctx)
		pronouns.object = _str(d, "object", entry_ctx)
		pronouns.possessive = _str(d, "possessive", entry_ctx)
		pronouns.reflexive = _str(d, "reflexive", entry_ctx)
		if pronouns.id.is_empty():
			errors.append("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(pronouns.id):
			errors.append("%s: duplicate id" % entry_ctx)
			continue
		out[pronouns.id] = pronouns
	if out.is_empty():
		errors.append("%s must not be empty" % ctx)
	return out


func _load_named_options(entries: Variant, ctx: String) -> Dictionary[String, NamedOption]:
	var out: Dictionary[String, NamedOption] = {}
	if not entries is Array:
		errors.append("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			errors.append("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var option := NamedOption.new()
		option.id = _str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, option.id]
		option.name = _str(d, "name", entry_ctx)
		if option.id.is_empty():
			errors.append("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(option.id):
			errors.append("%s: duplicate id" % entry_ctx)
			continue
		out[option.id] = option
	if out.is_empty():
		errors.append("%s must not be empty" % ctx)
	return out


func _load_color_options(entries: Variant, ctx: String) -> Dictionary[String, ColorOption]:
	var out: Dictionary[String, ColorOption] = {}
	if not entries is Array:
		errors.append("%s must be a list" % ctx)
		return out
	for entry: Variant in entries:
		if not entry is Dictionary:
			errors.append("%s: every entry must be an object" % ctx)
			continue
		var d: Dictionary = entry
		var option := ColorOption.new()
		option.id = _str(d, "id", ctx)
		var entry_ctx := "%s '%s'" % [ctx, option.id]
		option.name = _str(d, "name", entry_ctx)
		var color_text := _str(d, "color", entry_ctx)
		if Color.html_is_valid(color_text):
			option.color = Color.html(color_text)
		else:
			errors.append("%s: color '%s' is not a colour like #aabbcc" % [entry_ctx, color_text])
		if d.has("natural"):
			option.natural = _bool(d, "natural", entry_ctx)
		if option.id.is_empty():
			errors.append("%s: an entry has an empty 'id'" % ctx)
			continue
		if out.has(option.id):
			errors.append("%s: duplicate id" % entry_ctx)
			continue
		out[option.id] = option
	if out.is_empty():
		errors.append("%s must not be empty" % ctx)
	return out


# --- Clothing --------------------------------------------------------------------------

func _load_clothing(dir: String) -> void:
	_load_clothing_colours(dir.path_join("colours.json"))
	var items_dir := dir.path_join("items")
	var listing := DirAccess.open(items_dir)
	if listing == null:
		errors.append("%s: folder not found" % items_dir)
		return
	var files := listing.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() == "json":
			_load_clothing_items(items_dir.path_join(file))
	for slot: String in ClothingDef.REQUIRED_SLOTS:
		var found := false
		for item: ClothingDef in clothing.values():
			if item.slot == slot and item.starter:
				found = true
				break
		if not found:
			errors.append("%s: no starter item in required slot '%s' (a person always wears top, bottom and feet)" % [items_dir, slot])


func _load_clothing_colours(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root
	clothing_colours = _load_color_options(d.get("colours"), "%s: colours" % path)


func _load_clothing_items(path: String) -> void:
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in _arr(root, "items", path):
		if not entry is Dictionary:
			errors.append("%s: every item must be an object" % path)
			continue
		var d: Dictionary = entry
		var item := ClothingDef.new()
		item.id = _str(d, "id", path)
		var ctx := "%s: item '%s'" % [path, item.id]
		item.name = _str(d, "name", ctx)
		item.slot = _str(d, "slot", ctx)
		item.styles = _str_array(d, "styles", ctx)
		item.colours = _str_array(d, "colours", ctx)
		item.price = int(_num(d, "price", ctx))
		item.formality = int(_num(d, "formality", ctx))
		item.concealment = int(_num(d, "concealment", ctx))
		item.warmth = int(_num(d, "warmth", ctx))
		item.starter = _bool(d, "starter", ctx)
		if item.id.is_empty():
			errors.append("%s: an item has an empty 'id'" % path)
			continue
		if clothing.has(item.id):
			errors.append("%s: duplicate clothing id" % ctx)
			continue
		if not ClothingDef.SLOTS.has(item.slot):
			errors.append("%s: slot '%s' is not one of: %s" % [ctx, item.slot, ", ".join(ClothingDef.SLOTS)])
		for style: String in item.styles:
			if not ClothingDef.STYLES.has(style):
				errors.append("%s: style '%s' is not one of: %s" % [ctx, style, ", ".join(ClothingDef.STYLES)])
		if item.colours.is_empty():
			errors.append("%s: colours must not be empty" % ctx)
		for colour_id: String in item.colours:
			if not clothing_colours.has(colour_id):
				errors.append("%s: unknown colour '%s' (see data/clothing/colours.json)" % [ctx, colour_id])
		if item.price < 0:
			errors.append("%s: price %d is negative" % [ctx, item.price])
		if item.formality < -2 or item.formality > 3:
			errors.append("%s: formality %d must be -2..3" % [ctx, item.formality])
		if item.concealment < 0 or item.concealment > 3:
			errors.append("%s: concealment %d must be 0..3" % [ctx, item.concealment])
		if item.warmth < 0 or item.warmth > 3:
			errors.append("%s: warmth %d must be 0..3" % [ctx, item.warmth])
		clothing[item.id] = item


# --- World & districts -----------------------------------------------------------------

func _load_world(world_dir: String) -> void:
	var path := world_dir.path_join("world.json")
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return
	start_district = _str(root, "start_district", path)
	for entry: Variant in _arr(root, "districts", path):
		var district_id := String(entry)
		var district := _load_district(world_dir.path_join("districts").path_join(district_id), district_id)
		if district != null:
			districts[district_id] = district
			district_order.append(district_id)
	if not districts.has(start_district):
		errors.append("%s: start_district '%s' is not a loaded district" % [path, start_district])


func _load_district(dir: String, district_id: String) -> DistrictDef:
	var path := dir.path_join("district.json")
	var root: Variant = _read_json(path)
	if not root is Dictionary:
		return null
	var d: Dictionary = root
	var district := DistrictDef.new()
	district.id = _str(d, "id", path)
	district.name = _str(d, "name", path)
	if district.id != district_id:
		errors.append("%s: id '%s' must match its folder name '%s'" % [path, district.id, district_id])
	var origin := _arr(d, "origin", path)
	if origin.size() == 2:
		district.origin = Ser.to_vec2i(origin)
	else:
		errors.append("%s: origin must be [x, y]" % path)

	var level_files: Variant = d.get("levels")
	if not level_files is Dictionary or (level_files as Dictionary).is_empty():
		errors.append("%s: levels must map level numbers to files, e.g. {\"0\": \"level_0.txt\"}" % path)
		return null
	for key: Variant in level_files:
		var level := String(key).to_int()
		var rows := _read_rows(dir.path_join(String(level_files[key])))
		_validate_rows(rows, "%s level %d" % [path, level])
		district.levels[level] = rows
		if district.size == Vector2i.ZERO and not rows.is_empty():
			district.size = Vector2i(rows[0].length(), rows.size())

	var spawn := _arr(d, "player_spawn", path)
	if spawn.size() == 3:
		var local := Ser.to_cell(spawn)
		district.player_spawn = local + Vector3i(district.origin.x, district.origin.y, 0)
		_validate_spawn(district, local, path)
	else:
		errors.append("%s: player_spawn must be [x, y, level] (local to the district)" % path)

	for entry: Variant in _arr(d, "places", path):
		var pd: Dictionary = entry
		var place := PlaceDef.new()
		place.id = _str(pd, "id", path)
		var ctx := "%s: place '%s'" % [path, place.id]
		place.name = _str(pd, "name", ctx)
		place.kind = _str(pd, "kind", ctx)
		place.level = int(_num(pd, "level", ctx))
		var r := _arr(pd, "rect", ctx)
		if r.size() == 4:
			place.rect = Rect2i(int(r[0]) + district.origin.x, int(r[1]) + district.origin.y, int(r[2]), int(r[3]))
		else:
			errors.append("%s: rect must be [x, y, width, height] (local)" % ctx)
		district.places.append(place)
	return district


func _read_rows(path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return PackedStringArray()
	var text := FileAccess.get_file_as_string(path).replace("\r", "")
	var rows := text.split("\n")
	while not rows.is_empty() and rows[rows.size() - 1] == "":
		rows.remove_at(rows.size() - 1)
	return rows


func _validate_rows(rows: PackedStringArray, ctx: String) -> void:
	if rows.is_empty():
		errors.append("%s: map is empty" % ctx)
		return
	var width := rows[0].length()
	for y: int in rows.size():
		var row := rows[y]
		if row.length() != width:
			errors.append("%s: row %d has length %d, expected %d (all rows must be equally long)" % [ctx, y, row.length(), width])
		for x: int in row.length():
			if terrain_index_for_glyph(row[x]) < 0:
				errors.append("%s: unknown glyph '%s' at x=%d y=%d (see data/terrain.json)" % [ctx, row[x], x, y])


func _validate_spawn(district: DistrictDef, local: Vector3i, ctx: String) -> void:
	var rows: PackedStringArray = district.levels.get(local.z, PackedStringArray())
	if local.y < 0 or local.y >= rows.size() or local.x < 0 or local.x >= rows[local.y].length():
		errors.append("%s: player_spawn %s is outside the map" % [ctx, local])
		return
	var index := terrain_index_for_glyph(rows[local.y][local.x])
	if index >= 0 and not terrains[index].walkable:
		errors.append("%s: player_spawn %s is on '%s', which is not walkable" % [ctx, local, terrains[index].id])


# --- JSON readers (collect errors instead of crashing) ---------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


func _str(d: Dictionary, key: String, ctx: String) -> String:
	var v: Variant = d.get(key)
	if not v is String:
		errors.append("%s: '%s' must be a string" % [ctx, key])
		return ""
	return v


func _num(d: Dictionary, key: String, ctx: String) -> float:
	var v: Variant = d.get(key)
	if not (v is float or v is int):
		errors.append("%s: '%s' must be a number" % [ctx, key])
		return 0.0
	return float(v)


func _bool(d: Dictionary, key: String, ctx: String) -> bool:
	var v: Variant = d.get(key)
	if not v is bool:
		errors.append("%s: '%s' must be true or false" % [ctx, key])
		return false
	return v


func _arr(d: Dictionary, key: String, ctx: String) -> Array:
	var v: Variant = d.get(key)
	if not v is Array:
		errors.append("%s: '%s' must be a list" % [ctx, key])
		return []
	return v


func _obj(d: Dictionary, key: String, ctx: String) -> Dictionary:
	var v: Variant = d.get(key)
	if not v is Dictionary:
		errors.append("%s: '%s' must be an object" % [ctx, key])
		return {}
	return v


func _str_array(d: Dictionary, key: String, ctx: String) -> PackedStringArray:
	var v: Variant = d.get(key)
	if not v is Array:
		errors.append("%s: '%s' must be a list of strings" % [ctx, key])
		return PackedStringArray()
	var out := PackedStringArray()
	for entry: Variant in v:
		if not entry is String:
			errors.append("%s: every entry of '%s' must be a string" % [ctx, key])
			continue
		out.append(String(entry))
	return out
