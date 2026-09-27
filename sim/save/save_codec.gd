class_name SaveCodec
extends RefCounted
## Converts a whole Sim to a JSON-safe Dictionary and back. Pure: no file access here
## (game/session.gd reads and writes the files).
##
## RULES
## - Every piece of sim state must be in the save. If you add a field, save and load it;
##   tests/sim/test_save.gd runs "play, save, load, keep playing" and compares results.
## - If you change the SHAPE of saved data (rename, move, change meaning), bump
##   SAVE_VERSION, add a migration step in SaveMigrations, and add a fixture save to
##   tests/fixtures/saves/ made with the new version.

const SAVE_VERSION: int = 1


static func to_dict(sim: Sim) -> Dictionary:
	var pending: Array[Dictionary] = []
	for command: Command in sim.pending_commands():
		pending.append(CommandRegistry.encode(command))
	return {
		"save_version": SAVE_VERSION,
		"clock": sim.clock.to_dict(),
		"rng": sim.rng.to_dict(),
		"world": sim.world.to_dict(),
		"pending_commands": pending,
	}


## Returns null (and fills `errors`) if the save cannot be loaded.
static func from_dict(data: Dictionary, content: ContentDB, errors: Array[String] = []) -> Sim:
	var migrated := SaveMigrations.migrate(data, errors)
	if migrated.is_empty():
		return null
	var sim := Sim.new(
		content,
		World.from_dict(migrated["world"], content),
		SimClock.from_dict(migrated["clock"]),
		SimRng.from_dict(migrated["rng"]),
	)
	for entry: Variant in migrated["pending_commands"]:
		var command := CommandRegistry.decode(entry)
		if command != null:
			sim.submit(command)
	return sim


static func to_json(sim: Sim) -> String:
	return Ser.to_json(to_dict(sim))


## Returns null (and fills `errors`) if the text is not a loadable save.
static func from_json(text: String, content: ContentDB, errors: Array[String] = []) -> Sim:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("Save file is not valid JSON (line %d: %s)." % [json.get_error_line(), json.get_error_message()])
		return null
	if not json.data is Dictionary:
		errors.append("Save file does not contain a save.")
		return null
	return from_dict(json.data, content, errors)
