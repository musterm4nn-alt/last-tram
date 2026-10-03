class_name BackgroundLoader
extends RefCounted
## Loads data/backgrounds.json into ContentDB.backgrounds (T-0075). Runs after jobs, skills and
## moodlets, which it checks against.


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "backgrounds", path):
		if not entry is Dictionary:
			reader.error("%s: every background must be an object" % path)
			continue
		var d: Dictionary = entry
		var def := BackgroundDef.new()
		def.id = reader.read_str(d, "id", path)
		var ctx := "%s: background '%s'" % [path, def.id]
		def.name = reader.read_str(d, "name", ctx)
		def.description = reader.read_str(d, "description", ctx)
		def.cash = reader.read_int(d, "cash", ctx)
		def.bank = reader.read_int(d, "bank", ctx)
		def.job_id = reader.read_str(d, "job", ctx)
		def.skills = SkillLoader.read_amounts(db, reader, d, "skills", ctx)
		def.knows = reader.read_int(d, "knows", ctx)
		def.record = reader.read_bool(d, "record", ctx)
		if d.has("moodlet"):
			def.moodlet_id = reader.read_str(d, "moodlet", ctx)
			if db.moodlet(def.moodlet_id) == null:
				reader.error("%s: unknown moodlet '%s'" % [ctx, def.moodlet_id])
		if def.cash < 0 or def.bank < 0 or def.knows < 0:
			reader.error("%s: cash, bank and knows must be >= 0" % ctx)
		if not def.job_id.is_empty() and db.job(def.job_id) == null:
			reader.error("%s: unknown job '%s'" % [ctx, def.job_id])
		for skill_id: String in def.skills:
			if def.skills[skill_id] < 0 or def.skills[skill_id] > db.skill_rules.max_level:
				reader.error("%s: skill '%s' must be a level 0..%d" % [ctx, skill_id, db.skill_rules.max_level])
		if def.id.is_empty() or db.backgrounds.has(def.id):
			reader.error("%s: empty or duplicate background id" % ctx)
			continue
		db.backgrounds[def.id] = def
	db.default_background = reader.read_str(root, "default", path)
	if not db.backgrounds.has(db.default_background):
		reader.error("%s: 'default' must be one of the backgrounds" % path)
