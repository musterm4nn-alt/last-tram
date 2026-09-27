class_name NamesLoader
extends RefCounted
## Loads first/last names from data/names/names.json into a ContentDB (moved
## out of ContentDB so each content domain lives in a small file).


## Read `path` and fill `db.first_names` and `db.last_names`.
static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root
	var lists: Variant = d.get("first_names")
	if not lists is Dictionary:
		reader.error("%s: 'first_names' must be an object of name lists" % path)
	else:
		for key: Variant in lists:
			var list_id := String(key)
			db.first_names[list_id] = name_list(reader, lists[key], "%s: first_names '%s'" % [path, list_id])
		for list_id: String in ContentDB.FIRST_NAME_LISTS:
			if not db.first_names.has(list_id):
				reader.error("%s: first_names is missing the '%s' list" % [path, list_id])
	db.last_names = name_list(reader, d.get("last_names"), "%s: last_names" % path)


## One validated list of names. Problems are reported, bad entries skipped.
static func name_list(reader: ContentReader, value: Variant, ctx: String) -> PackedStringArray:
	var names := PackedStringArray()
	if not value is Array:
		reader.error("%s must be a list of names" % ctx)
		return names
	for entry: Variant in value:
		if not entry is String:
			reader.error("%s: every name must be a string" % ctx)
			continue
		var name := String(entry)
		if not Names.is_valid(name):
			reader.error("%s: '%s' is not a name (1..%d letters; spaces, hyphens and apostrophes allowed)" % [ctx, name, Names.MAX_LENGTH])
			continue
		names.append(name)
	if names.is_empty():
		reader.error("%s must not be empty" % ctx)
	return names
