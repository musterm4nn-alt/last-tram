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
	var p := reader.read_obj(root, "police", path)
	var police := db.police_rules
	for key: String in ["report_base", "report_per_severity", "friend_report_factor", "friend_at"]:
		police.set(key, reader.read_num(p, key, path + ": police"))
	police.heat_hours = reader.read_int(p, "heat_hours", path + ": police")
	police.severity_per_level = reader.read_int(p, "severity_per_level", path + ": police")
	police.fine_per_severity = reader.read_int(p, "fine_per_severity", path + ": police")
	police.arrest_range = reader.read_num(p, "arrest_range", path + ": police")
	police.officer_run_speed = reader.read_num(p, "officer_run_speed", path + ": police")
	if police.officer_run_speed <= 0.0:
		reader.error("%s: police officer_run_speed must be above 0" % path)
	for key: String in ["search_minutes", "search_radius", "lost_heat_hours"]:
		police.set(key, reader.read_int(p, key, path + ": police"))
	if police.search_minutes < 1 or police.search_radius < 1 or police.lost_heat_hours < 1:
		reader.error("%s: police search_minutes, search_radius and lost_heat_hours must be 1 or more" % path)
	if police.heat_hours < 1 or police.severity_per_level < 1:
		reader.error("%s: police heat_hours and severity_per_level must be 1 or more" % path)
	if police.fine_per_severity < 0 or police.arrest_range < 0.5 or police.arrest_range > 3.0:
		reader.error("%s: police fine_per_severity must be 0 or more and arrest_range 0.5 to 3" % path)
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
