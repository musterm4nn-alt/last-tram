class_name SkillLoader
extends RefCounted
## Loads data/skills.json into ContentDB.skills and ContentDB.skill_rules (T-0071). Runs before
## interactions and jobs, which name skills.

const EFFECTS: PackedStringArray = ["finish_bonus_per_level", "charisma_per_level", "performance_per_level", "interview_per_level"]


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var rules := db.skill_rules
	rules.max_level = reader.read_int(root, "max_level", path)
	rules.xp_per_level = reader.read_num(root, "xp_per_level", path)
	rules.work_xp_per_hour = reader.read_num(root, "work_xp_per_hour", path)
	if rules.max_level < 1 or rules.xp_per_level <= 0.0 or rules.work_xp_per_hour < 0.0:
		reader.error("%s: max_level >= 1, xp_per_level > 0 and work_xp_per_hour >= 0" % path)
	var effects := reader.read_obj(root, "effects", path)
	for key: String in EFFECTS:
		rules.set(key, reader.read_num(effects, key, path + ": effects"))
	for entry: Variant in reader.read_arr(root, "skills", path):
		if not entry is Dictionary:
			reader.error("%s: every skill must be an object" % path)
			continue
		var def := SkillDef.new()
		def.id = reader.read_str(entry, "id", path)
		def.name = reader.read_str(entry, "name", "%s: skill '%s'" % [path, def.id])
		if def.id.is_empty() or db.skills.has(def.id):
			reader.error("%s: empty or duplicate skill id '%s'" % [path, def.id])
			continue
		db.skills[def.id] = def


## Reads {skill_id: number} at `key` (unknown skills are errors); {} when absent.
static func read_amounts(db: ContentDB, reader: ContentReader, d: Dictionary, key: String, ctx: String) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	if not d.has(key):
		return out
	var raw := reader.read_obj(d, key, ctx)
	for skill_id: Variant in raw:
		if db.skill(String(skill_id)) == null:
			reader.error("%s: unknown skill '%s' in '%s'" % [ctx, skill_id, key])
		elif raw[skill_id] is float or raw[skill_id] is int:
			out[String(skill_id)] = float(raw[skill_id])
		else:
			reader.error("%s: '%s' amounts must be numbers" % [ctx, key])
	return out
