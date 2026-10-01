class_name InteractionLoader
extends RefCounted
## Loads interactions from every .json file in data/interactions/ into a
## ContentDB (same folder-of-files pattern as ObjectLoader).
##
## Every file has the same shape:
##   {"interactions": [{"id": "sleep", "name": "Sleep", "object_tags": ["bed"],
##     "until_need": "energy", "min_minutes": 60, "max_minutes": 720,
##     "need_rates": {"energy": 16.0}, "finish_needs": {},
##     "advertise": {"energy": 80}}]}
## A fixed-length interaction uses "duration_minutes" instead of "until_need"
## plus "min_minutes"/"max_minutes". Optional: "time_skip": true (the game skips ahead while
## the player does it, like sleeping), "routine": "sleep" | "out" (see Routines).


## Read `dir` (every sorted .json file) into `db.interactions`.
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


## Interactions from one interactions/*.json file.
static func load_file(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "interactions", path):
		if not entry is Dictionary:
			reader.error("%s: every interaction must be an object" % path)
			continue
		var d: Dictionary = entry
		var def := InteractionDef.new()
		def.id = reader.read_str(d, "id", path)
		var ctx := "%s: interaction '%s'" % [path, def.id]
		def.name = reader.read_str(d, "name", ctx)
		def.object_tags = reader.read_str_array(d, "object_tags", ctx)
		var has_duration := d.has("duration_minutes")
		var has_until := d.has("until_need")
		if has_duration:
			def.duration_minutes = int(reader.read_num(d, "duration_minutes", ctx))
		if has_until:
			def.until_need = reader.read_str(d, "until_need", ctx)
		if has_until:
			def.min_minutes = int(reader.read_num(d, "min_minutes", ctx))
			def.max_minutes = int(reader.read_num(d, "max_minutes", ctx))
		def.need_rates = _read_needs(reader, d, "need_rates", ctx)
		def.finish_needs = _read_needs(reader, d, "finish_needs", ctx)
		def.advertise = _read_needs(reader, d, "advertise", ctx)
		if d.has("time_skip"):
			def.time_skip = reader.read_bool(d, "time_skip", ctx)
		if d.has("finish_moodlet"):
			def.finish_moodlet = reader.read_str(d, "finish_moodlet", ctx)
			if db.moodlet(def.finish_moodlet) == null:
				reader.error("%s: unknown moodlet '%s' in 'finish_moodlet'" % [ctx, def.finish_moodlet])
		if d.has("routine"):
			def.routine = reader.read_str(d, "routine", ctx)
			if not def.routine in ["sleep", "out"]:
				reader.error("%s: 'routine' must be \"sleep\" or \"out\"" % ctx)
		if def.id.is_empty():
			reader.error("%s: an interaction has an empty 'id'" % path)
			continue
		if db.interaction(def.id) != null:
			reader.error("%s: duplicate interaction id" % ctx)
			continue
		if has_duration == has_until:
			reader.error("%s: exactly one of 'duration_minutes' or 'until_need' (with 'min_minutes' and 'max_minutes') is required" % ctx)
		if has_duration and def.duration_minutes <= 0:
			reader.error("%s: 'duration_minutes' must be > 0" % ctx)
		if has_until and def.min_minutes < 0:
			reader.error("%s: 'min_minutes' must be >= 0" % ctx)
		if has_until and def.max_minutes < maxi(def.min_minutes, 1):
			reader.error("%s: 'max_minutes' must be >= 'min_minutes' and >= 1" % ctx)
		if not has_until and (d.has("min_minutes") or d.has("max_minutes")):
			reader.error("%s: 'min_minutes'/'max_minutes' need 'until_need'" % ctx)
		if has_until and db.need(def.until_need) == null:
			reader.error("%s: unknown need '%s' in 'until_need'" % [ctx, def.until_need])
		for need_id: String in def.need_rates:
			if db.need(need_id) == null:
				reader.error("%s: unknown need '%s' in 'need_rates'" % [ctx, need_id])
		for need_id: String in def.finish_needs:
			if db.need(need_id) == null:
				reader.error("%s: unknown need '%s' in 'finish_needs'" % [ctx, need_id])
		for need_id: String in def.advertise:
			if db.need(need_id) == null:
				reader.error("%s: unknown need '%s' in 'advertise'" % [ctx, need_id])
		if def.object_tags.is_empty():
			reader.error("%s: 'object_tags' must not be empty" % ctx)
		for tag: String in def.object_tags:
			if not _any_object_uses(db, tag):
				reader.error("%s: tag '%s' is used by no object (see data/objects/)" % [ctx, tag])
		db.interactions[def.id] = def


## A {need_id: amount} map from `key` (missing or non-object reads as {} with an error).
static func _read_needs(reader: ContentReader, d: Dictionary, key: String, ctx: String) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	var obj := reader.read_obj(d, key, ctx)
	for need_id: Variant in obj:
		if not need_id is String:
			reader.error("%s: every key of '%s' must be a need id" % [ctx, key])
			continue
		var amount: Variant = obj[need_id]
		if not (amount is float or amount is int):
			reader.error("%s: '%s' amount for need '%s' must be a number" % [ctx, key, need_id])
			continue
		out[String(need_id)] = float(amount)
	return out


## True if at least one loaded object has `tag`.
static func _any_object_uses(db: ContentDB, tag: String) -> bool:
	for def: ObjectDef in db.objects.values():
		if tag in def.tags:
			return true
	return false
