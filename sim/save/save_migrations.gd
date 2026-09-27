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
	var version := int(data.get("save_version", 0))
	if version < 1:
		errors.append("Not a Last Tram save (no save_version).")
		return {}
	if version > SaveCodec.SAVE_VERSION:
		errors.append("Save is from a newer version of the game (v%d, this game reads up to v%d)." % [version, SaveCodec.SAVE_VERSION])
		return {}
	var d := data.duplicate(true)
	while version < SaveCodec.SAVE_VERSION:
		match version:
			# 1: d = _v1_to_v2(d)
			_:
				errors.append("No migration from save v%d." % version)
				return {}
		version += 1
		d["save_version"] = version
	return d
