class_name MoodletLoader
extends RefCounted
## Loads data/moodlets.json into ContentDB.moodlets.


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "moodlets", path):
		if not entry is Dictionary:
			reader.error("%s: every moodlet must be an object" % path)
			continue
		var d: Dictionary = entry
		var def := MoodletDef.new()
		def.id = reader.read_str(d, "id", path)
		var ctx := "%s: moodlet '%s'" % [path, def.id]
		def.name = reader.read_str(d, "name", ctx)
		def.value = reader.read_int(d, "value", ctx)
		def.duration_hours = reader.read_num(d, "duration_hours", ctx)
		if def.value < -100 or def.value > 100:
			reader.error("%s: 'value' must be within -100..100" % ctx)
		if def.duration_hours <= 0.0:
			reader.error("%s: 'duration_hours' must be > 0" % ctx)
		if def.id.is_empty():
			reader.error("%s: a moodlet has an empty 'id'" % path)
			continue
		if db.moodlets.has(def.id):
			reader.error("%s: duplicate moodlet id" % ctx)
			continue
		db.moodlets[def.id] = def
