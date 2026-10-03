class_name SavePersonValidator
extends RefCounted
## Validates nested person, appearance, outfit and action data before deserialization.


## Checks all state read by Person.from_dict(), returning action ids for uniqueness checks.
static func validate(p: Dictionary, s: SaveSchema, path: String, version: int) -> Array[int]:
	for key: String in ["first_name", "last_name"]:
		s.text(p.get(key), path + "." + key)
	for key: String in ["nickname", "gender", "pronouns"]:
		s.text(p.get(key, ""), path + "." + key)
	s.integer(p.get("age_years", 18), path + ".age_years", Person.MIN_AGE)
	s.integer(p.get("level"), path + ".level", -2147483648, 2147483647)
	for key: String in ["pos", "facing", "move_intent"]:
		s.vector(p.get(key), path + "." + key, 2)
	s.number(p.get("walk_speed"), path + ".walk_speed", 0.0)
	s.boolean(p.get("free_will", true), path + ".free_will")
	s.boolean(p.get("running", false), path + ".running")
	s.integer(p.get("home_lot_id", 0), path + ".home_lot_id")
	s.integer(p.get("household_id", 0), path + ".household_id")
	s.integer(p.get("autonomy_retry_tick", 0), path + ".autonomy_retry_tick")
	s.text(p.get("routine_id", ""), path + ".routine_id")
	s.boolean(p.get("background", false), path + ".background")
	for scene_id: Variant in s.list(p.get("scenes_requested", []), path + ".scenes_requested"):
		s.text(scene_id, path + ".scenes_requested[]")
	s.text(p.get("origin", ""), path + ".origin")
	s.boolean(p.get("record", false), path + ".record")
	var dirt := s.dictionary(p.get("dirt", {}), path + ".dirt")
	for piece: Variant in dirt:
		s.number(dirt[piece], path + ".dirt." + str(piece), 0.0, 100.0)
	var skills := s.dictionary(p.get("skills", {}), path + ".skills")
	for id: Variant in skills:
		s.number(skills[id], path + ".skills." + str(id), 0.0)
	for key: String in ["known_clues", "discoveries"]:
		for id: Variant in s.list(p.get(key, []), path + "." + key):
			s.text(id, path + "." + key + "[]")
	_wallet(s.dictionary(p.get("wallet", {}), path + ".wallet"), s, path + ".wallet")
	s.boolean(p.get("benefit_registered", false), path + ".benefit_registered")
	s.integer(p.get("applied_day", -1), path + ".applied_day", -1)
	if p.get("job") != null:
		var job := s.dictionary(p.get("job"), path + ".job")
		s.text(job.get("job_id"), path + ".job.job_id")
		for key: String in ["position", "level", "hired_day"]:
			s.integer(job.get(key, 0), path + ".job." + key)
		s.number(job.get("performance", 50.0), path + ".job.performance", 0.0, 100.0)
		for key: String in ["unpaid", "level_shifts", "shifts_worked", "shifts_missed"]:
			s.integer(job.get(key, 0), path + ".job." + key)
		s.integer(job.get("last_shift_start", -1), path + ".job.last_shift_start", -1)
		s.integer(job.get("shift_start", -1), path + ".job.shift_start", -1)
		for key: String in ["shift_minutes", "shift_late"]:
			s.integer(job.get(key, 0), path + ".job." + key)
		s.boolean(job.get("warned", false), path + ".job.warned")
		s.boolean(job.get("shift_lunch", false), path + ".job.shift_lunch")
	var others: Dictionary[int, bool] = {}
	for entry: Variant in s.list(p.get("relationships", []), path + ".relationships"):
		var r := s.dictionary(entry, path + ".relationships[]")
		var other := s.integer(r.get("other_id"), path + ".relationships[].other_id", 1)
		if others.has(other):
			s.reject(path + ".relationships", "one relationship per person")
		others[other] = true
		for key: String in Relationship.RANGES:
			var bounds: Array = Relationship.RANGES[key]
			s.number(r.get(key, 0.0), path + ".relationships[]." + key, float(bounds[0]), float(bounds[1]))
		s.integer(r.get("last_contact_tick", 0), path + ".relationships[].last_contact_tick", -SaveSchema.MAX_INTEGER)
	for entry: Variant in s.list(p.get("memories", []), path + ".memories"):
		var m := s.dictionary(entry, path + ".memories[]")
		s.integer(m.get("tick"), path + ".memories[].tick", -SaveSchema.MAX_INTEGER)
		s.text(m.get("kind"), path + ".memories[].kind")
		for subject: Variant in s.list(m.get("subject_ids", []), path + ".memories[].subject_ids"):
			s.integer(subject, path + ".memories[].subject_ids[]")
		s.text(m.get("place_id", ""), path + ".memories[].place_id")
		s.integer(m.get("valence", 0), path + ".memories[].valence", -100, 100)
		s.number(m.get("salience", 0.0), path + ".memories[].salience", 0.0, 100.0)
		if not s.text(m.get("source", Memory.EXPERIENCED), path + ".memories[].source") in [Memory.EXPERIENCED, Memory.WITNESSED, Memory.HEARD]:
			s.reject(path + ".memories[].source", "unknown memory source")
		s.integer(m.get("source_id", 0), path + ".memories[].source_id")
	for entry: Variant in s.list(p.get("moodlets", []), path + ".moodlets"):
		var m := s.dictionary(entry, path + ".moodlets[]")
		s.text(m.get("id"), path + ".moodlets[].id")
		s.integer(m.get("ends_tick"), path + ".moodlets[].ends_tick", -SaveSchema.MAX_INTEGER)
	s.integer(p.get("last_input_tick", 0), path + ".last_input_tick")
	for entry: Variant in s.list(p.get("path", []), path + ".path"):
		s.vector(entry, path + ".path[]", 3, true)
	var needs := s.dictionary(p.get("needs", {}), path + ".needs")
	for key: Variant in needs:
		s.text(key, path + ".needs key")
		s.number(needs[key], path + ".needs." + str(key), 0.0, 100.0)
	_appearance(s.dictionary(p.get("appearance", {}), path + ".appearance"), s, path + ".appearance")
	for entry: Variant in s.list(p.get("wardrobe", []), path + ".wardrobe"):
		var owned := s.dictionary(entry, path + ".wardrobe[]")
		s.text(owned.get("item", ""), path + ".wardrobe[].item")
		s.text(owned.get("colour", ""), path + ".wardrobe[].colour")
	var saved := s.dictionary(p.get("outfits", {}), path + ".outfits")
	for name: Variant in saved:
		s.text(name, path + ".outfits key")
		s.dictionary(saved[name], path + ".outfits." + str(name))
	var outfit := s.dictionary(p.get("outfit", {}), path + ".outfit")
	for key: Variant in outfit:
		s.text(key, path + ".outfit key")
		var worn := s.dictionary(outfit[key], path + ".outfit." + str(key))
		s.text(worn.get("item", ""), path + ".outfit item")
		s.text(worn.get("colour", ""), path + ".outfit colour")
	var personality := s.dictionary(p.get("personality", {}), path + ".personality")
	for axis: String in Personality.AXES:
		if personality.has(axis):
			s.integer(personality[axis], path + ".personality." + axis, Personality.MIN_VALUE, Personality.MAX_VALUE)
	var ids: Array[int] = []
	var queue := s.list(p.get("action_queue", []), path + ".action_queue")
	if queue.size() > Person.MAX_QUEUE:
		s.reject(path + ".action_queue", "queue exceeds its capacity")
	for i: int in queue.size():
		var action_path := "%s.action_queue[%d]" % [path, i]
		var action := s.dictionary(queue[i], action_path)
		if version >= 3:
			ids.append(s.integer(action.get("id"), action_path + ".id", 1))
		s.text(action.get("interaction_id", ""), action_path + ".interaction_id")
		s.integer(action.get("target_id", 0), action_path + ".target_id")
		s.integer(action.get("slot_index", -1), action_path + ".slot_index", -1)
		var state := s.text(action.get("state", Action.QUEUED), action_path + ".state")
		if not state in [Action.QUEUED, Action.ROUTING, Action.PERFORMING]:
			s.reject(action_path + ".state", "unknown action state")
		s.integer(action.get("minutes_done", 0), action_path + ".minutes_done")
		var started := s.integer(action.get("started_tick", -1), action_path + ".started_tick", -1)
		if state == Action.PERFORMING and (started < 0 or s.integer(action.get("slot_index", -1), action_path + ".slot_index", -1) < 0):
			s.reject(action_path, "performing actions need a start tick and use slot")
		if i > 0 and state != Action.QUEUED:
			s.reject(action_path, "only the front action may be active")
	return ids


static func _wallet(w: Dictionary, s: SaveSchema, path: String) -> void:
	s.integer(w.get("cash", 0), path + ".cash")
	s.integer(w.get("bank", 0), path + ".bank", -SaveSchema.MAX_INTEGER)
	var entries := s.list(w.get("statement", []), path + ".statement")
	if entries.size() > Wallet.STATEMENT_SIZE:
		s.reject(path + ".statement", "statement exceeds its size")
	for entry: Variant in entries:
		var e := s.dictionary(entry, path + ".statement[]")
		s.integer(e.get("tick"), path + ".statement[].tick", -SaveSchema.MAX_INTEGER)
		s.integer(e.get("amount"), path + ".statement[].amount", -SaveSchema.MAX_INTEGER)
		if not s.text(e.get("account"), path + ".statement[].account") in [Money.CASH, Money.BANK]:
			s.reject(path + ".statement[].account", "unknown account")
		s.text(e.get("reason"), path + ".statement[].reason")
		s.text(e.get("detail", ""), path + ".statement[].detail")


static func _appearance(a: Dictionary, s: SaveSchema, path: String) -> void:
	for key: String in ["skin_tone", "build", "hair_style", "hair_colour", "eye_colour", "facial_hair"]:
		s.text(a.get(key, ""), path + "." + key)
	s.integer(a.get("height_cm", 175), path + ".height_cm", 1)
	s.strings(a.get("features", []), path + ".features")
