class_name NeedsLoader
extends RefCounted
## Loads needs from data/needs.json into a ContentDB (moved out of ContentDB
## so each content domain lives in a small file).


## Read `path` and fill `db.needs` plus the need lookup table.
static func load(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "needs", path):
		if not entry is Dictionary:
			reader.error("%s: every need must be an object" % path)
			continue
		var d: Dictionary = entry
		var n := NeedDef.new()
		n.id = reader.read_str(d, "id", path)
		var ctx := "%s: need '%s'" % [path, n.id]
		n.name = reader.read_str(d, "name", ctx)
		n.decay_per_hour = reader.read_num(d, "decay_per_hour", ctx)
		n.start = reader.read_num(d, "start", ctx)
		n.urgency_weight = reader.read_num(d, "urgency_weight", ctx)
		n.critical_below = reader.read_num(d, "critical_below", ctx)
		if n.id.is_empty():
			reader.error("%s: need id must not be empty" % path)
		if db._need_by_id.has(n.id):
			reader.error("%s: duplicate need id" % ctx)
		if n.decay_per_hour < 0.0:
			reader.error("%s: 'decay_per_hour' must be >= 0" % ctx)
		if n.start < 0.0 or n.start > 100.0:
			reader.error("%s: 'start' must be within 0..100" % ctx)
		if n.critical_below < 0.0 or n.critical_below > 100.0:
			reader.error("%s: 'critical_below' must be within 0..100" % ctx)
		if n.urgency_weight <= 0.0:
			reader.error("%s: 'urgency_weight' must be > 0" % ctx)
		db._need_by_id[n.id] = n
		db.needs.append(n)
