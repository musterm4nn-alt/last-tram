class_name CrimeLoader
extends RefCounted
## Loads data/crimes.json into ContentDB.crimes (T-0091). Runs before interactions, which
## name crimes.

const MAX_SEVERITY: int = 8


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "crimes", path):
		if not entry is Dictionary:
			reader.error("%s: every crime must be an object" % path)
			continue
		var def := CrimeDef.new()
		def.id = reader.read_str(entry, "id", path)
		var ctx := "%s: crime '%s'" % [path, def.id]
		def.name = reader.read_str(entry, "name", ctx)
		def.severity = reader.read_int(entry, "severity", ctx)
		if def.id.is_empty() or db.crimes.has(def.id):
			reader.error("%s: empty or duplicate crime id '%s'" % [path, def.id])
			continue
		if def.severity < 1 or def.severity > MAX_SEVERITY:
			reader.error("%s: severity must be 1 to %d" % [ctx, MAX_SEVERITY])
			continue
		db.crimes[def.id] = def
