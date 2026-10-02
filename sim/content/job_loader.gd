class_name JobLoader
extends RefCounted
## Loads data/jobs.json into ContentDB.jobs (T-0058). Runs after WorldLoader: a job's
## workplace object must be placed on its place.

const DAY_NAMES: PackedStringArray = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "jobs", path):
		if not entry is Dictionary:
			reader.error("%s: every job must be an object" % path)
			continue
		var d: Dictionary = entry
		var job := JobDef.new()
		job.id = reader.read_str(d, "id", path)
		var ctx := "%s: job '%s'" % [path, job.id]
		job.name = reader.read_str(d, "name", ctx)
		job.place_id = reader.read_str(d, "place_id", ctx)
		job.session = reader.read_str(d, "session", ctx)
		job.workplace_tag = reader.read_str(d, "workplace_tag", ctx)
		job.start_filled = reader.read_num(d, "start_filled", ctx)
		if d.has("formality"):
			job.formality = reader.read_num(d, "formality", ctx)
		var rates := reader.read_obj(d, "need_rates", ctx)
		for need_id: Variant in rates:
			if db.need(String(need_id)) == null:
				reader.error("%s: unknown need '%s' in 'need_rates'" % [ctx, need_id])
			elif rates[need_id] is float or rates[need_id] is int:
				job.need_rates[String(need_id)] = float(rates[need_id])
		if d.has("shift_moodlet"):
			job.shift_moodlet = reader.read_str(d, "shift_moodlet", ctx)
			if db.moodlet(job.shift_moodlet) == null:
				reader.error("%s: unknown moodlet '%s' in 'shift_moodlet'" % [ctx, job.shift_moodlet])
		_read_levels(reader, d, job, ctx)
		_read_positions(reader, d, job, ctx)
		if not JobDef.SESSIONS.has(job.session):
			reader.error("%s: 'session' must be one of %s" % [ctx, ", ".join(JobDef.SESSIONS)])
		if job.start_filled < 0.0 or job.start_filled > 1.0:
			reader.error("%s: 'start_filled' must be within 0..1" % ctx)
		if db.place(job.place_id) == null:
			reader.error("%s: unknown place '%s'" % [ctx, job.place_id])
		elif not _workplace_placed(db, job):
			reader.error("%s: no object tagged '%s' stands on '%s'" % [ctx, job.workplace_tag, job.place_id])
		if job.id.is_empty() or db.jobs.has(job.id):
			reader.error("%s: empty or duplicate job id" % ctx)
			continue
		db.jobs[job.id] = job
	var player_job := db.economy.player_job
	if not player_job.is_empty() and not db.jobs.has(player_job):
		reader.error("economy.json: 'player_job' '%s' is not a job in %s" % [player_job, path])
	check_staffed(db, reader)


static func _read_levels(reader: ContentReader, d: Dictionary, job: JobDef, ctx: String) -> void:
	for entry: Variant in reader.read_arr(d, "levels", ctx):
		if not entry is Dictionary:
			reader.error("%s: every level must be an object" % ctx)
			continue
		var level := JobLevel.new()
		level.title = reader.read_str(entry, "title", ctx + " level")
		level.wage = reader.read_int(entry, "wage", ctx + " level")
		if level.wage <= 0:
			reader.error("%s: level '%s' needs a wage > 0" % [ctx, level.title])
		job.levels.append(level)
	if job.levels.is_empty():
		reader.error("%s: 'levels' must not be empty" % ctx)


static func _read_positions(reader: ContentReader, d: Dictionary, job: JobDef, ctx: String) -> void:
	for entry: Variant in reader.read_arr(d, "positions", ctx):
		if not entry is Dictionary:
			reader.error("%s: every position must be an object" % ctx)
			continue
		var p: Dictionary = entry
		var shift := ShiftDef.new()
		for day: String in reader.read_str_array(p, "days", ctx + " position"):
			if not DAY_NAMES.has(day):
				reader.error("%s: unknown day '%s' (use mon … sun)" % [ctx, day])
			elif not shift.days.has(DAY_NAMES.find(day)):
				shift.days.append(DAY_NAMES.find(day))
		shift.from = reader.read_int(p, "from", ctx + " position")
		shift.to = reader.read_int(p, "to", ctx + " position")
		if shift.from < 0 or shift.from > 24 or shift.to < 0 or shift.to > 24 or shift.from == shift.to:
			reader.error("%s: a position needs two different whole hours 0..24" % ctx)
		if shift.days.is_empty():
			reader.error("%s: a position needs at least one day" % ctx)
		var count := reader.read_int(p, "count", ctx + " position") if p.has("count") else 1
		if count < 1:
			reader.error("%s: 'count' must be >= 1" % ctx)
		for i: int in count:
			job.positions.append(shift)
	if job.positions.is_empty():
		reader.error("%s: 'positions' must not be empty" % ctx)


## True if some placed object of the districts has the job's tag and stands on its place.
static func _workplace_placed(db: ContentDB, job: JobDef) -> bool:
	var place := db.place(job.place_id)
	for district_id: String in db.district_order:
		for placement: ObjectPlacement in db.districts[district_id].objects:
			var def := db.object_def(placement.def_id)
			if def != null and def.tags.has(job.workplace_tag) and place.contains(placement.cell):
				return true
	return false


## Every placed object that offers a staffed interaction (T-0065) must stand on a place with
## an on-site job, or nobody could ever serve there.
static func check_staffed(db: ContentDB, reader: ContentReader) -> void:
	for district_id: String in db.district_order:
		for placement: ObjectPlacement in db.districts[district_id].objects:
			var def := db.object_def(placement.def_id)
			if def == null:
				continue
			for interaction: InteractionDef in db.interactions.values():
				if not interaction.staffed or not _offers(def, interaction):
					continue
				var place := db.place_at(placement.cell)
				if place == null or not _has_on_site_job(db, place.id):
					reader.error("%s: '%s' at %s offers staffed '%s', but no on-site job works there" % [
						district_id, def.id, placement.cell, interaction.id])


static func _offers(def: ObjectDef, interaction: InteractionDef) -> bool:
	for tag: String in interaction.object_tags:
		if def.tags.has(tag):
			return true
	return false


static func _has_on_site_job(db: ContentDB, place_id: String) -> bool:
	for job: JobDef in db.jobs.values():
		if job.session == JobDef.ON_SITE and job.place_id == place_id:
			return true
	return false
