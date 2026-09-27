class_name ObjectLoader
extends RefCounted
## Loads world-object definitions from every .json file in data/objects/ into a
## ContentDB (moved out of ContentDB so each content domain lives in a small file).
##
## Every file has the same shape:
##   {"objects": [{"id": "fridge", "name": "Fridge", "size": [1, 1],
##     "blocks_movement": true, "blocks_sight": false, "tags": ["fridge"],
##     "use_slots": [{"offset": [0, 1], "facing": [0, -1]}],
##     "price": 45000, "debug_color": "#dfe6e9"}]}

## Unit cardinal vectors a use-slot facing may hold.
const CARDINALS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## Read `dir` (every sorted .json file) into `db.objects`.
static func load(db: ContentDB, reader: ContentReader, dir: String) -> void:
	var listing := DirAccess.open(dir)
	if listing == null:
		reader.error("%s: folder not found" % dir)
		return
	var files := listing.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() == "json":
			load_file(db, reader, dir.path_join(file))


## Object definitions from one objects/*.json file.
static func load_file(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "objects", path):
		if not entry is Dictionary:
			reader.error("%s: every object must be an object" % path)
			continue
		var d: Dictionary = entry
		var def := ObjectDef.new()
		def.id = reader.read_str(d, "id", path)
		var ctx := "%s: object '%s'" % [path, def.id]
		def.name = reader.read_str(d, "name", ctx)
		def.size = _read_size(reader, d, ctx)
		def.blocks_movement = reader.read_bool(d, "blocks_movement", ctx)
		def.blocks_sight = reader.read_bool(d, "blocks_sight", ctx)
		def.tags = reader.read_str_array(d, "tags", ctx)
		def.use_slots = _read_slots(reader, d, ctx)
		def.price = int(reader.read_num(d, "price", ctx))
		var color_text := reader.read_str(d, "debug_color", ctx)
		if Color.html_is_valid(color_text):
			def.debug_color = Color.html(color_text)
		else:
			reader.error("%s: debug_color '%s' is not a colour like #aabbcc" % [ctx, color_text])
		if def.id.is_empty():
			reader.error("%s: an object has an empty 'id'" % path)
			continue
		if db.object_def(def.id) != null:
			reader.error("%s: duplicate object id" % ctx)
			continue
		if def.size.x < 1 or def.size.y < 1:
			reader.error("%s: size %s must be [width, height] with each >= 1" % [ctx, def.size])
		if def.use_slots.is_empty():
			reader.error("%s: must have at least one use slot" % ctx)
		if def.price < 0:
			reader.error("%s: price %d must be >= 0" % [ctx, def.price])
		db.objects[def.id] = def


static func _read_size(reader: ContentReader, d: Dictionary, ctx: String) -> Vector2i:
	var arr := reader.read_arr(d, "size", ctx)
	if arr.size() != 2:
		reader.error("%s: size must be [width, height]" % ctx)
		return Vector2i.ONE
	if not (arr[0] is float or arr[0] is int) or not (arr[1] is float or arr[1] is int):
		reader.error("%s: size must be [width, height]" % ctx)
		return Vector2i.ONE
	return Vector2i(int(arr[0]), int(arr[1]))


static func _read_slots(reader: ContentReader, d: Dictionary, ctx: String) -> Array[UseSlotDef]:
	var out: Array[UseSlotDef] = []
	var index := 0
	for entry: Variant in reader.read_arr(d, "use_slots", ctx):
		var slot_ctx := "%s: use slot %d" % [ctx, index]
		index += 1
		if not entry is Dictionary:
			reader.error("%s must be an object" % slot_ctx)
			continue
		var slot_dict: Dictionary = entry
		var slot := UseSlotDef.new()
		slot.offset = _read_vec2i(reader, slot_dict, "offset", slot_ctx)
		slot.facing = _read_vec2i(reader, slot_dict, "facing", slot_ctx)
		if not slot.facing in CARDINALS:
			reader.error("%s: facing %s must be a unit cardinal vector (one of [1,0], [-1,0], [0,1], [0,-1])" % [slot_ctx, slot.facing])
		out.append(slot)
	return out


static func _read_vec2i(reader: ContentReader, d: Dictionary, key: String, ctx: String) -> Vector2i:
	var arr := reader.read_arr(d, key, ctx)
	if arr.size() != 2:
		reader.error("%s: '%s' must be [x, y]" % [ctx, key])
		return Vector2i.ZERO
	if not (arr[0] is float or arr[0] is int) or not (arr[1] is float or arr[1] is int):
		reader.error("%s: '%s' must be [x, y]" % [ctx, key])
		return Vector2i.ZERO
	return Vector2i(int(arr[0]), int(arr[1]))
