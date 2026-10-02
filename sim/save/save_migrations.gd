class_name SaveMigrations
extends RefCounted
## Upgrades old save dictionaries, one version at a time, to SaveCodec.SAVE_VERSION.
##
## To change the save format:
##   1. bump SaveCodec.SAVE_VERSION (say to 2)
##   2. write `static func _v1_to_v2(d: Dictionary) -> Dictionary` below and add it to STEPS
##   3. add a fixture made with the new version to tests/fixtures/saves/
## Never edit an existing migration step once it has been merged.


## Returns the migrated dictionary, or {} (and fills `errors`) if it cannot be migrated.
static func migrate(data: Dictionary, errors: Array[String] = []) -> Dictionary:
	var initial := errors.size()
	var version := SaveSchema.new(errors).integer(data.get("save_version"), "save_version", 1)
	if errors.size() != initial:
		return {}
	if version < 1:
		errors.append("Not a Last Tram save (no save_version).")
		return {}
	if version > SaveCodec.SAVE_VERSION:
		errors.append("Save is from a newer version of the game (v%d, this game reads up to v%d)." % [version, SaveCodec.SAVE_VERSION])
		return {}
	var d := data.duplicate(true)
	while version < SaveCodec.SAVE_VERSION:
		match version:
			1:
				d = _v1_to_v2(d)
			2:
				d = _v2_to_v3(d)
			3:
				d = _v3_to_v4(d)
			4:
				d = _v4_to_v5(d)
			5:
				d = _v5_to_v6(d)
			6:
				d = _v6_to_v7(d)
			7:
				d = _v7_to_v8(d)
			8:
				d = _v8_to_v9(d)
			9:
				d = _v9_to_v10(d)
			10:
				d = _v10_to_v11(d)
			11:
				d = _v11_to_v12(d)
			_:
				errors.append("No migration from save v%d." % version)
				return {}
		version += 1
		d["save_version"] = version
	return d


## v12 (T-0065): Café Wolke gets its counter (the barista's workplace), as in new towns.
## Saves that already have one, or have no objects (test rooms), are left alone.
static func _v11_to_v12(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("objects") is Array:
		return d
	var world: Dictionary = d["world"]
	var objects: Array = world["objects"]
	if objects.is_empty():
		return d
	for obj: Variant in objects:
		if obj is Dictionary and obj.get("def_id") == "cafe_counter":
			return d
	var id := _int(world.get("next_id"), 1)
	objects.append({"id": id, "def_id": "cafe_counter", "origin": [21, 13, 0], "rotation": 2})
	world["next_id"] = id + 1
	return d


## v11 (T-0077): the world's work setting (jobs are varied, the owner's default), and
## whether the attended shift has had its lunch (a shift saved after lunchtime has).
static func _v10_to_v11(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	d["world"]["work"] = {"gentle": false}
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary and person.get("job") is Dictionary:
			var job: Dictionary = person["job"]
			job["shift_lunch"] = _int(job.get("shift_minutes"), 0) >= 180  # lunch_after_minutes when v11 was made
	return d


## v10 (T-0077): a job remembers the shift being attended. Someone saved while working
## (a performing "work" action at the front) is attending the shift that started at
## last_shift_start (v9 set it on arrival), with the minutes they worked inside it so far.
static func _v9_to_v10(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("people", []) is Array:
		return d
	var per_minute := 20  # SimClock.STEPS_PER_GAME_MINUTE when v10 was made
	for person: Variant in d["world"].get("people", []):
		if not person is Dictionary or not person.get("job") is Dictionary:
			continue
		var job: Dictionary = person["job"]
		job.merge({"shift_start": -1, "shift_minutes": 0, "shift_late": 0})
		var queue: Variant = person.get("action_queue", [])
		var front: Variant = queue[0] if queue is Array and not queue.is_empty() else null
		var start := _int(job.get("last_shift_start"), -1)
		if not front is Dictionary or front.get("interaction_id") != "work" or front.get("state") != "performing" or start < 0:
			continue
		var started := _int(front.get("started_tick"), start)
		var before_start := maxi(0, ceili(float(start - started) / per_minute))
		job["shift_start"] = start
		job["shift_minutes"] = maxi(0, _int(front.get("minutes_done"), 0) - before_start)
		job["shift_late"] = maxi(0, (started - start) / per_minute)
	return d


## A number from a save dictionary as an int, or `fallback` (validation comes later).
static func _int(value: Variant, fallback: int) -> int:
	return int(value) if value is int or value is float else fallback


## v9 (T-0064): nobody has applied for a job yet.
static func _v8_to_v9(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("people", []) is Array:
		return d
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary:
			person["applied_day"] = -1
	return d


## v8 (T-0062): residents are registered for benefit (the player isn't), and home lots owe
## nothing yet.
static func _v7_to_v8(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("people", []) is Array:
		return d
	var world: Dictionary = d["world"]
	for person: Variant in world.get("people", []):
		if person is Dictionary:
			person["benefit_registered"] = person.get("id") != world.get("player_id")
	return d


## v7 jobs keep pay and performance records (T-0061): nothing earned or missed yet.
static func _v6_to_v7(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("people", []) is Array:
		return d
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary and person.get("job") is Dictionary:
			var job: Dictionary = person["job"]
			job.merge({"unpaid": 0, "level_shifts": 0, "shifts_worked": 0, "shifts_missed": 0, "warned": false, "last_shift_start": -1})
	return d


## v6 people may have a job (T-0058): nobody had one before.
static func _v5_to_v6(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("people", []) is Array:
		return d
	for person: Variant in d["world"].get("people", []):
		if person is Dictionary:
			person["job"] = null
	return d


## v5 households have groceries (T-0057): every fridge starts with 10 portions.
static func _v4_to_v5(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary or not d["world"].get("households", []) is Array:
		return d
	for household: Variant in d["world"].get("households", []):
		if household is Dictionary:
			household["groceries"] = 10
	return d


## v4 people have money (T-0054): everyone gets €40 cash and €300 in the bank, and the ledger
## records it as starting money so old towns balance.
static func _v3_to_v4(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	var world: Dictionary = d["world"]
	if not world.get("people") is Array:
		return d
	var count := 0
	for person: Variant in world["people"]:
		if person is Dictionary:
			person["wallet"] = {"cash": 4000, "bank": 30000, "statement": []}
			count += 1
	world["ledger"] = {"sources": {"start": 34000 * count}, "sinks": {}}
	return d


## v3 actions have stable instance ids. Preserve earned minutes and their elapsed phase.
static func _v2_to_v3(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	var world: Dictionary = d["world"]
	if not world.get("people") is Array:
		return d
	var next_id_value: Variant = world.get("next_id")
	if not (next_id_value is int or next_id_value is float):
		return d
	var next_id := int(next_id_value)
	for entry: Variant in world["people"]:
		if not entry is Dictionary or not entry.get("action_queue", []) is Array:
			continue
		for action: Variant in entry.get("action_queue", []):
			if not action is Dictionary:
				continue
			action["id"] = next_id
			next_id += 1
	world["next_id"] = next_id
	return d


## v1 people have no identity, appearance or outfit: everyone gets the default look.
static func _v1_to_v2(d: Dictionary) -> Dictionary:
	if not d.get("world") is Dictionary:
		return d
	var world: Dictionary = d["world"]
	if not world.get("people") is Array:
		return d
	for person: Variant in world["people"]:
		if not person is Dictionary:
			continue
		var p: Dictionary = person
		p["nickname"] = ""
		p["gender"] = "nonbinary"
		p["pronouns"] = "they"
		p["age_years"] = 27
		p["appearance"] = {
			"skin_tone": "skin_04",
			"height_cm": 174,
			"build": "average",
			"hair_style": "short",
			"hair_colour": "dark_brown",
			"eye_colour": "hazel",
			"facial_hair": "none",
			"features": [],
		}
		p["outfit"] = {
			"top": {"item": "t_shirt", "colour": "black"},
			"bottom": {"item": "jeans", "colour": "denim"},
			"feet": {"item": "trainers", "colour": "white"},
			"outer": {"item": "hoodie", "colour": "grey"},
		}
	return d
