class_name RoutineLoader
extends RefCounted
## Loads data/routines.json into a ContentDB (routines and the default routine id).


static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "routines", path):
		if not entry is Dictionary:
			reader.error("%s: every routine must be an object" % path)
			continue
		var d: Dictionary = entry
		var routine := RoutineDef.new()
		routine.id = reader.read_str(d, "id", path)
		var ctx := "%s: routine '%s'" % [path, routine.id]
		routine.name = reader.read_str(d, "name", ctx)
		var hours := reader.read_coordinates(d, "sleep_hours", ctx, 2)
		if hours.size() == 2:
			if hours[0] < 0 or hours[0] > 24 or hours[1] < 0 or hours[1] > 24 or hours[0] == hours[1]:
				reader.error("%s: sleep_hours must be two different whole hours 0..24" % ctx)
			routine.sleep_hours = Vector2i(hours[0], hours[1])
		var out := reader.read_coordinates(d, "out_hours", ctx, 2)
		if out.size() == 2:
			if out[0] < 0 or out[0] > 24 or out[1] < 0 or out[1] > 24 or out[0] == out[1]:
				reader.error("%s: out_hours must be two different whole hours 0..24" % ctx)
			routine.out_hours = Vector2i(out[0], out[1])
		routine.weight = reader.read_int(d, "weight", ctx)
		if routine.weight < 0:
			reader.error("%s: 'weight' must be >= 0" % ctx)
		if routine.id.is_empty():
			reader.error("%s: a routine has an empty 'id'" % path)
			continue
		if db.routines.has(routine.id):
			reader.error("%s: duplicate routine id" % ctx)
			continue
		db.routines[routine.id] = routine
	db.default_routine = reader.read_str(root, "default", path)
	if not db.routines.has(db.default_routine):
		reader.error("%s: default routine '%s' is not defined" % [path, db.default_routine])
