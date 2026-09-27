class_name TerrainLoader
extends RefCounted
## Loads terrain types from data/terrain.json into a ContentDB (moved out of
## ContentDB so each content domain lives in a small file).


## Read `path` and fill `db.terrains` plus the terrain lookup tables.
static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "terrains", path):
		if not entry is Dictionary:
			reader.error("%s: every terrain must be an object" % path)
			continue
		var d: Dictionary = entry
		var t := TerrainDef.new()
		t.id = reader.read_str(d, "id", path)
		var ctx := "%s: terrain '%s'" % [path, t.id]
		t.name = reader.read_str(d, "name", ctx)
		t.glyph = reader.read_str(d, "glyph", ctx)
		t.walkable = reader.read_bool(d, "walkable", ctx)
		t.blocks_sight = reader.read_bool(d, "blocks_sight", ctx)
		t.indoor = reader.read_bool(d, "indoor", ctx)
		t.surface = reader.read_str(d, "surface", ctx)
		t.path_cost = reader.read_num(d, "path_cost", ctx)
		if t.path_cost < 1.0:
			reader.error("%s: 'path_cost' %s must be >= 1.0" % [ctx, t.path_cost])
		var color_text := reader.read_str(d, "debug_color", ctx)
		if Color.html_is_valid(color_text):
			t.debug_color = Color.html(color_text)
		else:
			reader.error("%s: debug_color '%s' is not a colour like #aabbcc" % [ctx, color_text])
		if t.glyph.length() != 1:
			reader.error("%s: glyph must be exactly one character" % ctx)
		if db.terrain_index(t.id) >= 0:
			reader.error("%s: duplicate terrain id" % ctx)
		if db.terrain_index_for_glyph(t.glyph) >= 0:
			reader.error("%s: glyph '%s' already used by another terrain" % [ctx, t.glyph])
		db.add_terrain(t)
	if db.terrain_index("void") < 0:
		reader.error("%s: a terrain with id 'void' is required (used outside the map)" % path)
