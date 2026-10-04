class_name CrimeLoader
extends RefCounted
## Loads data/crimes.json into ContentDB.crimes (T-0091). Runs before interactions, which
## name crimes.

const MAX_SEVERITY: int = 8


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var w := reader.read_obj(root, "witness", path)
	var rules := db.witness_rules
	for key: String in ["day_range", "night_range", "night_from", "night_until", "memory_valence"]:
		rules.set(key, reader.read_int(w, key, path + ": witness"))
	rules.memory_salience = reader.read_num(w, "memory_salience", path + ": witness")
	if rules.day_range < 1 or rules.night_range < 1 or rules.night_from > 23 or rules.night_until > 23:
		reader.error("%s: witness ranges must be 1 or more and hours 0-23" % path)
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
