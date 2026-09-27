class_name WorldLoader
extends RefCounted
## Loads districts, level maps and places from data/world/ into a ContentDB
## (moved out of ContentDB so each content domain lives in a small file).


## Read `world_dir` (world.json plus every listed district) into the world tables.
static func load(db: ContentDB, reader: ContentReader, world_dir: String) -> void:
	var path := world_dir.path_join("world.json")
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	db.start_district = reader.read_str(root, "start_district", path)
	for entry: Variant in reader.read_arr(root, "districts", path):
		var district_id := String(entry)
		var district := load_district(db, reader, world_dir.path_join("districts").path_join(district_id), district_id)
		if district != null:
			db.districts[district_id] = district
			db.district_order.append(district_id)
	if not db.districts.has(db.start_district):
		reader.error("%s: start_district '%s' is not a loaded district" % [path, db.start_district])


## One district folder (district.json plus level maps). Null if unloadable.
static func load_district(db: ContentDB, reader: ContentReader, dir: String, district_id: String) -> DistrictDef:
	var path := dir.path_join("district.json")
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return null
	var d: Dictionary = root
	var district := DistrictDef.new()
	district.id = reader.read_str(d, "id", path)
	district.name = reader.read_str(d, "name", path)
	if district.id != district_id:
		reader.error("%s: id '%s' must match its folder name '%s'" % [path, district.id, district_id])
	var origin := reader.read_arr(d, "origin", path)
	if origin.size() == 2:
		district.origin = Ser.to_vec2i(origin)
	else:
		reader.error("%s: origin must be [x, y]" % path)

	var level_files: Variant = d.get("levels")
	if not level_files is Dictionary or (level_files as Dictionary).is_empty():
		reader.error("%s: levels must map level numbers to files, e.g. {\"0\": \"level_0.txt\"}" % path)
		return null
	for key: Variant in level_files:
		var level := String(key).to_int()
		var rows := read_rows(reader, dir.path_join(String(level_files[key])))
		validate_rows(db, reader, rows, "%s level %d" % [path, level])
		district.levels[level] = rows
		if district.size == Vector2i.ZERO and not rows.is_empty():
			district.size = Vector2i(rows[0].length(), rows.size())

	var spawn := reader.read_arr(d, "player_spawn", path)
	if spawn.size() == 3:
		var local := Ser.to_cell(spawn)
		district.player_spawn = local + Vector3i(district.origin.x, district.origin.y, 0)
		validate_spawn(db, reader, district, local, path)
	else:
		reader.error("%s: player_spawn must be [x, y, level] (local to the district)" % path)

	for entry: Variant in reader.read_arr(d, "places", path):
		var pd: Dictionary = entry
		var place := PlaceDef.new()
		place.id = reader.read_str(pd, "id", path)
		var ctx := "%s: place '%s'" % [path, place.id]
		place.name = reader.read_str(pd, "name", ctx)
		place.kind = reader.read_str(pd, "kind", ctx)
		place.level = int(reader.read_num(pd, "level", ctx))
		var r := reader.read_arr(pd, "rect", ctx)
		if r.size() == 4:
			place.rect = Rect2i(int(r[0]) + district.origin.x, int(r[1]) + district.origin.y, int(r[2]), int(r[3]))
		else:
			reader.error("%s: rect must be [x, y, width, height] (local)" % ctx)
		district.places.append(place)
	return district


## The ASCII rows of one level map file.
static func read_rows(reader: ContentReader, path: String) -> PackedStringArray:
	if not FileAccess.file_exists(path):
		reader.error("%s: file not found" % path)
		return PackedStringArray()
	var text := FileAccess.get_file_as_string(path).replace("\r", "")
	var rows := text.split("\n")
	while not rows.is_empty() and rows[rows.size() - 1] == "":
		rows.remove_at(rows.size() - 1)
	return rows


## Every row is equally long and uses only known terrain glyphs.
static func validate_rows(db: ContentDB, reader: ContentReader, rows: PackedStringArray, ctx: String) -> void:
	if rows.is_empty():
		reader.error("%s: map is empty" % ctx)
		return
	var width := rows[0].length()
	for y: int in rows.size():
		var row := rows[y]
		if row.length() != width:
			reader.error("%s: row %d has length %d, expected %d (all rows must be equally long)" % [ctx, y, row.length(), width])
		for x: int in row.length():
			if db.terrain_index_for_glyph(row[x]) < 0:
				reader.error("%s: unknown glyph '%s' at x=%d y=%d (see data/terrain.json)" % [ctx, row[x], x, y])


## The spawn cell exists and is walkable.
static func validate_spawn(db: ContentDB, reader: ContentReader, district: DistrictDef, local: Vector3i, ctx: String) -> void:
	var rows: PackedStringArray = district.levels.get(local.z, PackedStringArray())
	if local.y < 0 or local.y >= rows.size() or local.x < 0 or local.x >= rows[local.y].length():
		reader.error("%s: player_spawn %s is outside the map" % [ctx, local])
		return
	var index := db.terrain_index_for_glyph(rows[local.y][local.x])
	if index >= 0 and not db.terrains[index].walkable:
		reader.error("%s: player_spawn %s is on '%s', which is not walkable" % [ctx, local, db.terrains[index].id])
