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

var terrains: Array[TerrainDef] = []
var districts: Dictionary[String, DistrictDef] = {}
## District ids in the order they are stamped into the world.
var district_order: Array[String] = []
var start_district: String = ""
var errors: PackedStringArray = []

var _terrain_by_id: Dictionary[String, int] = {}
var _terrain_by_glyph: Dictionary[String, int] = {}


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_from(DATA_ROOT)
	return db


func load_from(root: String) -> void:
	_load_terrains(root.path_join("terrain.json"))
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


## The place containing a world cell, or null.
func place_at(cell: Vector3i) -> PlaceDef:
	for district_id: String in district_order:
		for place: PlaceDef in districts[district_id].places:
			if place.contains(cell):
				return place
	return null


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
