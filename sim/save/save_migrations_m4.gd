class_name SaveMigrationsM4
extends RefCounted
## Save migrations added in M4 (called from SaveMigrations.migrate).


## v19 → v20 (T-0091): the world keeps incidents (crimes committed); none before.
static func v19_to_v20(d: Dictionary) -> Dictionary:
	if d.get("world") is Dictionary:
		d["world"]["incidents"] = []
	return d
