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
	s.integer(p.get("last_input_tick", 0), path + ".last_input_tick")
	for entry: Variant in s.list(p.get("path", []), path + ".path"):
		s.vector(entry, path + ".path[]", 3, true)
	var needs := s.dictionary(p.get("needs", {}), path + ".needs")
	for key: Variant in needs:
		s.text(key, path + ".needs key")
		s.number(needs[key], path + ".needs." + str(key), 0.0, 100.0)
	_appearance(s.dictionary(p.get("appearance", {}), path + ".appearance"), s, path + ".appearance")
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


static func _appearance(a: Dictionary, s: SaveSchema, path: String) -> void:
	for key: String in ["skin_tone", "build", "hair_style", "hair_colour", "eye_colour", "facial_hair"]:
		s.text(a.get(key, ""), path + "." + key)
	s.integer(a.get("height_cm", 175), path + ".height_cm", 1)
	s.strings(a.get("features", []), path + ".features")
