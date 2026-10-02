class_name WorldLoader
extends RefCounted
## Loads districts, level maps and places from data/world/ into a ContentDB
## (moved out of ContentDB so each content domain lives in a small file).


## Read `world_dir` (world.json plus every listed district) into the world tables.
static func load(db: ContentDB, reader: ContentReader, world_dir: String) -> void:
	var path := world_dir.path_join("world.json")
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		reader.error("%s: world must be an object" % path)
		return
	db.start_district = reader.read_str(root, "start_district", path)
	for district_id: String in reader.read_str_array(root, "districts", path):
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
		reader.error("%s: district must be an object" % path)
		return null
	var d: Dictionary = root
	var district := DistrictDef.new()
	district.id = reader.read_str(d, "id", path)
	district.name = reader.read_str(d, "name", path)
	if district.id != district_id:
		reader.error("%s: id '%s' must match its folder name '%s'" % [path, district.id, district_id])
	var origin := reader.read_coordinates(d, "origin", path, 2)
	if origin.size() == 2:
		district.origin = Ser.to_vec2i(origin)
	else:
		reader.error("%s: origin must be [x, y]" % path)

	var level_files: Variant = d.get("levels")
	if not level_files is Dictionary or (level_files as Dictionary).is_empty():
		reader.error("%s: levels must map level numbers to files, e.g. {\"0\": \"level_0.txt\"}" % path)
		return null
	for key: Variant in level_files:
		if not key is String or key.length() > 11 or not key.is_valid_int() or str(key.to_int()) != key or key.to_int() < -2147483648 or key.to_int() > 2147483647:
			reader.error("%s: level keys must be integer strings" % path)
			continue
		var level: int = key.to_int()
		var filename := reader.read_str(level_files, key, path)
		if filename.is_empty():
			continue
		var rows := read_rows(reader, dir.path_join(filename))
		validate_rows(db, reader, rows, "%s level %d" % [path, level])
		district.levels[level] = rows
		if district.size == Vector2i.ZERO and not rows.is_empty():
			district.size = Vector2i(rows[0].length(), rows.size())

	var spawn := reader.read_coordinates(d, "player_spawn", path, 3)
	if spawn.size() == 3:
		var local := Ser.to_cell(spawn)
		district.player_spawn = local + Vector3i(district.origin.x, district.origin.y, 0)
		validate_spawn(db, reader, district, local, path)
	else:
		reader.error("%s: player_spawn must be [x, y, level] (local to the district)" % path)

	for entry: Variant in reader.read_arr(d, "places", path):
		if not entry is Dictionary:
			reader.error("%s: every place must be an object" % path)
			continue
		var pd: Dictionary = entry
		var place := PlaceDef.new()
		place.id = reader.read_str(pd, "id", path)
		var ctx := "%s: place '%s'" % [path, place.id]
		place.name = reader.read_str(pd, "name", ctx)
		place.kind = reader.read_str(pd, "kind", ctx)
		place.level = reader.read_int(pd, "level", ctx)
		var r := reader.read_coordinates(pd, "rect", ctx, 4)
		if r.size() == 4:
			place.rect = Rect2i(int(r[0]) + district.origin.x, int(r[1]) + district.origin.y, int(r[2]), int(r[3]))
		else:
			reader.error("%s: rect must be [x, y, width, height] (local)" % ctx)
		_read_access(reader, pd, place, ctx)
		if place.kind == "home":
			place.rent = reader.read_int(pd, "rent", ctx)
			if place.rent <= 0:
				reader.error("%s: a home's \"rent\" must be > 0 (euro cents per week)" % ctx)
		elif pd.has("rent"):
			reader.error("%s: only homes have \"rent\"" % ctx)
		district.places.append(place)
	load_objects(db, reader, district, dir)
	return district


## Kinds whose places are businesses: they must have opening hours.
const BUSINESS_KINDS: PackedStringArray = ["shop", "cafe", "bar", "restaurant"]


## Reads a place's optional "access" and "hours" (see PlaceDef), with defaults by kind.
static func _read_access(reader: ContentReader, pd: Dictionary, place: PlaceDef, ctx: String) -> void:
	if pd.has("access"):
		place.access = reader.read_str(pd, "access", ctx)
	elif place.kind == "home":
		place.access = Lot.PRIVATE
	elif BUSINESS_KINDS.has(place.kind):
		place.access = Lot.HOURS
	else:
		place.access = Lot.PUBLIC
	if not Lot.ACCESS.has(place.access):
		reader.error("%s: access '%s' must be one of %s" % [ctx, place.access, ", ".join(Lot.ACCESS)])
		place.access = Lot.PUBLIC
	if place.access != Lot.HOURS:
		if pd.has("hours"):
			reader.error("%s: \"hours\" only applies to access \"hours\"" % ctx)
		if pd.has("closed"):
			reader.error("%s: \"closed\" only applies to access \"hours\"" % ctx)
		return
	for day: String in reader.read_str_array(pd, "closed", ctx) if pd.has("closed") else PackedStringArray():
		var weekday := Array(SimClock.WEEKDAY_NAMES).map(func(n: String) -> String: return n.to_lower()).find(day)
		if weekday < 0:
			reader.error("%s: unknown day '%s' in \"closed\" (use mon … sun)" % [ctx, day])
		elif not place.closed_days.has(weekday):
			place.closed_days.append(weekday)
	if not pd.has("hours"):
		reader.error("%s: access \"hours\" needs \"hours\": [open_hour, close_hour]" % ctx)
		return
	var hours := reader.read_coordinates(pd, "hours", ctx, 2)
	if hours.is_empty():
		return  # read_coordinates reported it
	if hours[0] < 0 or hours[0] > 24 or hours[1] < 0 or hours[1] > 24:
		reader.error("%s: hours must be [open_hour, close_hour], whole hours 0..24" % ctx)
		return
	place.open_hour = hours[0]
	place.close_hour = hours[1]


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


## Authored object placements from the district's optional objects.json (local
## coordinates). Invalid placements are reported and skipped. Error messages name
## the file, the object and the problem.
static func load_objects(db: ContentDB, reader: ContentReader, district: DistrictDef, dir: String) -> void:
	var path := dir.path_join("objects.json")
	if not FileAccess.file_exists(path):
		return
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		reader.error("%s: object placements must be an object" % path)
		return
	var occupied: Dictionary = {}
	var placed: Array[ObjectPlacement] = []
	for entry: Variant in reader.read_arr(root, "objects", path):
		if not entry is Dictionary:
			reader.error("%s: every object must be an object" % path)
			continue
		var od: Dictionary = entry
		var def_id := reader.read_str(od, "def", path)
		var ctx := "%s: object '%s'" % [path, def_id]
		var cell_arr := reader.read_coordinates(od, "cell", ctx, 3)
		var rotation := reader.read_int(od, "rotation", ctx)
		if cell_arr.size() != 3 or not _is_num(cell_arr[0]) or not _is_num(cell_arr[1]) or not _is_num(cell_arr[2]):
			reader.error("%s: cell must be [x, y, level] (local to the district)" % ctx)
			continue
		var local := Vector3i(int(cell_arr[0]), int(cell_arr[1]), int(cell_arr[2]))
		if rotation < 0 or rotation > 3:
			reader.error("%s: rotation %d must be 0..3" % [ctx, rotation])
			continue
		var def := db.object_def(def_id)
		if def == null:
			reader.error("%s: unknown object '%s'" % [path, def_id])
			continue
		var world_cell := local + Vector3i(district.origin.x, district.origin.y, 0)
		var footprint: Array[Vector3i] = []
		for offset: Vector2i in def.footprint(rotation):
			footprint.append(world_cell + Vector3i(offset.x, offset.y, 0))
		var bad := false
		for foot: Vector3i in footprint:
			var foot_local := foot - Vector3i(district.origin.x, district.origin.y, 0)
			if not _local_in_bounds(district, foot_local):
				reader.error("%s: object '%s' at %s is outside the district" % [path, def_id, local])
				bad = true
				break
			if not _local_walkable(db, district, foot_local):
				reader.error("%s: object '%s' at %s is on '%s', which is not walkable" % [path, def_id, local, _terrain_id_at(db, district, foot_local)])
				bad = true
				break
		if bad:
			continue
		for foot: Vector3i in footprint:
			if occupied.has(foot):
				reader.error("%s: object '%s' at %s overlaps another object" % [path, def_id, local])
				bad = true
				break
		if bad:
			continue
		var placement := ObjectPlacement.new()
		placement.def_id = def_id
		placement.cell = world_cell
		placement.rotation = rotation
		placed.append(placement)
		for foot: Vector3i in footprint:
			occupied[foot] = true
	# Second pass, once every object is placed: a later object may cover an earlier one's slots.
	for placement: ObjectPlacement in placed:
		if _has_usable_slot(db, district, placement, occupied):
			district.objects.append(placement)
		else:
			var local := placement.cell - Vector3i(district.origin.x, district.origin.y, 0)
			reader.error("%s: object '%s' at %s has no usable use slot (every slot is blocked or not walkable)" % [path, placement.def_id, local])


## True if at least one use slot of `placement` is inside the district, walkable and not
## covered by any placed object (`occupied` holds every placed footprint cell).
static func _has_usable_slot(db: ContentDB, district: DistrictDef, placement: ObjectPlacement, occupied: Dictionary) -> bool:
	var def := db.object_def(placement.def_id)
	for slot: UseSlotDef in def.use_slots:
		var rotated := ObjectDef.rotate_offset(slot.offset, def.size, placement.rotation)
		var slot_world := placement.cell + Vector3i(rotated.x, rotated.y, 0)
		var slot_local := slot_world - Vector3i(district.origin.x, district.origin.y, 0)
		if _local_walkable(db, district, slot_local) and not occupied.has(slot_world):
			return true
	return false


static func _is_num(v: Variant) -> bool:
	return v is float or v is int


static func _local_in_bounds(district: DistrictDef, local: Vector3i) -> bool:
	if not district.levels.has(local.z):
		return false
	var rows: PackedStringArray = district.levels[local.z]
	if local.y < 0 or local.y >= rows.size():
		return false
	if local.x < 0 or local.x >= rows[local.y].length():
		return false
	if local.x >= district.size.x or local.y >= district.size.y:
		return false
	return true


static func _local_walkable(db: ContentDB, district: DistrictDef, local: Vector3i) -> bool:
	if not _local_in_bounds(district, local):
		return false
	var rows: PackedStringArray = district.levels[local.z]
	var index := db.terrain_index_for_glyph(rows[local.y][local.x])
	if index < 0:
		return false
	return db.terrains[index].walkable


static func _terrain_id_at(db: ContentDB, district: DistrictDef, local: Vector3i) -> String:
	if not district.levels.has(local.z):
		return "void"
	var rows: PackedStringArray = district.levels[local.z]
	if local.y < 0 or local.y >= rows.size() or local.x < 0 or local.x >= rows[local.y].length():
		return "void"
	var index := db.terrain_index_for_glyph(rows[local.y][local.x])
	if index < 0:
		return "unknown"
	return db.terrains[index].id
