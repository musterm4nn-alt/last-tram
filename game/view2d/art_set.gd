class_name ArtSet
extends RefCounted
## One art set for the 2D view: which part of which sheet draws each terrain and object,
## read from data/art2d/<set>.json (format: data/art2d/README.md). View only; the sim never
## sees it. Anything the set doesn't map (or maps wrongly) draws as a placeholder, so art
## can arrive gradually. An empty set (ArtSet.new()) maps nothing.

const DEFAULT_ROOT: String = "res://data/art2d"

## The file name without ".json"; "" for the empty set.
var id: String = ""
var name: String = ""
## Problems found while loading. The entries they concern were dropped.
var errors: Array[String] = []
## Optional colours of thin walls (T-0085): any of "top", "edge", "face", "glass".
var thin_walls: Dictionary = {}

var _sheets: Dictionary[String, Texture2D] = {}
## terrain id -> {"sheet": String, "cell": Vector2i, "variants": int}
var _terrain: Dictionary[String, Dictionary] = {}
## object def id -> {"sheet": String, "rects": Array[Rect2i]} (1 rect, or 4 by rotation)
var _objects: Dictionary[String, Dictionary] = {}


## Loads `<root>/<set_id>.json`. Never null: problems go to `errors`.
static func load_set(set_id: String, content: ContentDB, root: String = DEFAULT_ROOT) -> ArtSet:
	var art := ArtSet.new()
	art.id = set_id
	var reader := ContentReader.new()
	var path := "%s/%s.json" % [root, set_id]
	var data: Variant = reader.read_json(path)
	if data is Dictionary:
		art._read(data, content, reader, path)
	elif data != null:
		reader.error("%s: must be an object" % path)
	art.errors.append_array(reader.errors)
	return art


## The tile for a terrain at a map cell: {"texture": Texture2D, "region": Rect2i}, or {}.
func terrain_tile(terrain_id: String, cell: Vector2i) -> Dictionary:
	if not _terrain.has(terrain_id):
		return {}
	var entry: Dictionary = _terrain[terrain_id]
	var px := ViewConfig.TILE_PX
	var tile: Vector2i = entry["cell"] + Vector2i(variant_index(cell, int(entry["variants"])), 0)
	return {"texture": _sheets[entry["sheet"]], "region": Rect2i(tile * px, Vector2i(px, px))}


## The sprite for an object def at a rotation (0-3): {"texture": Texture2D, "region": Rect2i}, or {}.
func object_sprite(def_id: String, rotation: int) -> Dictionary:
	if not _objects.has(def_id):
		return {}
	var entry: Dictionary = _objects[def_id]
	var rects: Array[Rect2i] = entry["rects"]
	var region: Rect2i = rects[0] if rects.size() == 1 else rects[posmod(rotation, 4)]
	return {"texture": _sheets[entry["sheet"]], "region": region}


## Which of `variants` tiles a map cell uses: a fixed hash, the same on every run.
static func variant_index(cell: Vector2i, variants: int) -> int:
	if variants <= 1:
		return 0
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return posmod(h ^ (h >> 16), variants)


func _read(data: Dictionary, content: ContentDB, reader: ContentReader, path: String) -> void:
	name = reader.read_str(data, "name", path)
	var sheets := reader.read_obj(data, "sheets", path)
	for sheet_name: Variant in sheets:
		var sheet_path: Variant = sheets[sheet_name]
		var ctx := "%s: sheet '%s'" % [path, sheet_name]
		if not sheet_path is String or not ResourceLoader.exists(sheet_path):
			reader.error("%s: file not found (%s)" % [ctx, sheet_path])
			continue
		var texture := load(sheet_path) as Texture2D
		if texture == null:
			reader.error("%s: not an image (%s)" % [ctx, sheet_path])
			continue
		_sheets[str(sheet_name)] = texture
	if data.has("terrain"):
		var terrain := reader.read_obj(data, "terrain", path)
		for terrain_id: Variant in terrain:
			_read_terrain(str(terrain_id), terrain[terrain_id], content, reader, path)
	if data.has("thin_walls"):
		var colors := reader.read_obj(data, "thin_walls", path)
		for key: Variant in colors:
			var ctx := "%s: thin_walls '%s'" % [path, key]
			if not str(key) in ["top", "edge", "face", "glass"]:
				reader.error("%s: unknown colour (use top, edge, face, glass)" % ctx)
			elif not colors[key] is String or not Color.html_is_valid(colors[key]):
				reader.error("%s: must be a colour like \"#aabbcc\"" % ctx)
			else:
				thin_walls[str(key)] = Color(colors[key])
	if data.has("objects"):
		var objects := reader.read_obj(data, "objects", path)
		for def_id: Variant in objects:
			_read_object(str(def_id), objects[def_id], content, reader, path)


func _read_terrain(terrain_id: String, value: Variant, content: ContentDB, reader: ContentReader, path: String) -> void:
	var ctx := "%s: terrain '%s'" % [path, terrain_id]
	if content.terrain_index(terrain_id) < 0:
		reader.error("%s: no such terrain" % ctx)
		return
	if not value is Dictionary:
		reader.error("%s: must be an object" % ctx)
		return
	var d: Dictionary = value
	var texture := _sheet(d, reader, ctx)
	var cell := reader.read_coordinates(d, "cell", ctx, 2)
	var variants: int = reader.read_int(d, "variants", ctx) if d.has("variants") else 1
	if texture == null or cell.is_empty():
		return
	if variants < 1:
		reader.error("%s: 'variants' must be 1 or more" % ctx)
		return
	var px := ViewConfig.TILE_PX
	var region := Rect2i(cell[0] * px, cell[1] * px, px * variants, px)
	if not _inside(region, texture):
		reader.error("%s: cell %s (with %d variants) is outside the sheet" % [ctx, cell, variants])
		return
	_terrain[terrain_id] = {"sheet": d["sheet"], "cell": Vector2i(cell[0], cell[1]), "variants": variants}


func _read_object(def_id: String, value: Variant, content: ContentDB, reader: ContentReader, path: String) -> void:
	var ctx := "%s: object '%s'" % [path, def_id]
	if content.object_def(def_id) == null:
		reader.error("%s: no such object" % ctx)
		return
	if not value is Dictionary:
		reader.error("%s: must be an object" % ctx)
		return
	var d: Dictionary = value
	var texture := _sheet(d, reader, ctx)
	var lists: Array = []
	if d.has("rects"):
		lists = reader.read_arr(d, "rects", ctx)
		if lists.size() != 4:
			reader.error("%s: 'rects' must list 4 rects, one per rotation" % ctx)
			return
	else:
		lists = [d.get("rect")]
	var rects: Array[Rect2i] = []
	for value_rect: Variant in lists:
		var r := reader.read_coordinates({"rect": value_rect}, "rect", ctx, 4)
		if r.is_empty():
			return
		var rect := Rect2i(r[0], r[1], r[2], r[3])
		if rect.size.x < 1 or rect.size.y < 1:
			reader.error("%s: rect %s must have a size of at least 1x1" % [ctx, r])
			return
		if texture != null and not _inside(rect, texture):
			reader.error("%s: rect %s is outside the sheet" % [ctx, r])
			return
		rects.append(rect)
	if texture != null:
		_objects[def_id] = {"sheet": d["sheet"], "rects": rects}


## The loaded sheet named by d["sheet"], or null (with an error).
func _sheet(d: Dictionary, reader: ContentReader, ctx: String) -> Texture2D:
	var sheet_name := reader.read_str(d, "sheet", ctx)
	if sheet_name.is_empty():
		return null
	if not _sheets.has(sheet_name):
		reader.error("%s: no loaded sheet '%s'" % [ctx, sheet_name])
		return null
	return _sheets[sheet_name]


static func _inside(region: Rect2i, texture: Texture2D) -> bool:
	return region.position.x >= 0 and region.position.y >= 0 \
			and Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(region)
