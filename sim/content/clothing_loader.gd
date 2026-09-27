class_name ClothingLoader
extends RefCounted
## Loads clothing colours and items from data/clothing/ into a ContentDB (moved
## out of ContentDB so each content domain lives in a small file).


## Read `dir` (colours.json plus every file in items/) into the clothing tables.
static func load(db: ContentDB, reader: ContentReader, dir: String) -> void:
	load_colours(db, reader, dir.path_join("colours.json"))
	var items_dir := dir.path_join("items")
	var listing := DirAccess.open(items_dir)
	if listing == null:
		reader.error("%s: folder not found" % items_dir)
		return
	var files := listing.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() == "json":
			load_items(db, reader, items_dir.path_join(file))
	for slot: String in ClothingDef.REQUIRED_SLOTS:
		var found := false
		for item: ClothingDef in db.clothing.values():
			if item.slot == slot and item.starter:
				found = true
				break
		if not found:
			reader.error("%s: no starter item in required slot '%s' (a person always wears top, bottom and feet)" % [items_dir, slot])


## Colour options from colours.json (same shape as appearance colours).
static func load_colours(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root
	db.clothing_colours = AppearanceLoader.load_color_options(reader, d.get("colours"), "%s: colours" % path)


## Clothing items from one items/*.json file.
static func load_items(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "items", path):
		if not entry is Dictionary:
			reader.error("%s: every item must be an object" % path)
			continue
		var d: Dictionary = entry
		var item := ClothingDef.new()
		item.id = reader.read_str(d, "id", path)
		var ctx := "%s: item '%s'" % [path, item.id]
		item.name = reader.read_str(d, "name", ctx)
		item.slot = reader.read_str(d, "slot", ctx)
		item.styles = reader.read_str_array(d, "styles", ctx)
		item.colours = reader.read_str_array(d, "colours", ctx)
		item.price = int(reader.read_num(d, "price", ctx))
		item.formality = int(reader.read_num(d, "formality", ctx))
		item.concealment = int(reader.read_num(d, "concealment", ctx))
		item.warmth = int(reader.read_num(d, "warmth", ctx))
		item.starter = reader.read_bool(d, "starter", ctx)
		if item.id.is_empty():
			reader.error("%s: an item has an empty 'id'" % path)
			continue
		if db.clothing.has(item.id):
			reader.error("%s: duplicate clothing id" % ctx)
			continue
		if not ClothingDef.SLOTS.has(item.slot):
			reader.error("%s: slot '%s' is not one of: %s" % [ctx, item.slot, ", ".join(ClothingDef.SLOTS)])
		for style: String in item.styles:
			if not ClothingDef.STYLES.has(style):
				reader.error("%s: style '%s' is not one of: %s" % [ctx, style, ", ".join(ClothingDef.STYLES)])
		if item.colours.is_empty():
			reader.error("%s: colours must not be empty" % ctx)
		for colour_id: String in item.colours:
			if not db.clothing_colours.has(colour_id):
				reader.error("%s: unknown colour '%s' (see data/clothing/colours.json)" % [ctx, colour_id])
		if item.price < 0:
			reader.error("%s: price %d is negative" % [ctx, item.price])
		if item.formality < -2 or item.formality > 3:
			reader.error("%s: formality %d must be -2..3" % [ctx, item.formality])
		if item.concealment < 0 or item.concealment > 3:
			reader.error("%s: concealment %d must be 0..3" % [ctx, item.concealment])
		if item.warmth < 0 or item.warmth > 3:
			reader.error("%s: warmth %d must be 0..3" % [ctx, item.warmth])
		db.clothing[item.id] = item
