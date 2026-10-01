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
			_:
				errors.append("No migration from save v%d." % version)
				return {}
		version += 1
		d["save_version"] = version
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
