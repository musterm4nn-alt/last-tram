class_name DialogueLoader
extends RefCounted
## Loads every .json file in data/dialogue/ into ContentDB.dialogue (merged; T-0040). Lines
## must name person-targeted interactions and known outcomes; thoughts must name needs.


static func load(db: ContentDB, reader: ContentReader, dir: String) -> void:
	var listing := DirAccess.open(dir)
	if listing == null:
		reader.error("%s: folder not found" % dir)
		return
	var files := listing.get_files()
	files.sort()
	for file: String in files:
		if file.get_extension() == "json":
			_load_file(db, reader, dir.path_join(file))


static func _load_file(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	var d: Dictionary = root
	if d.has("topics"):
		db.dialogue.topics.append_array(reader.read_str_array(d, "topics", path))
	if d.has("lines"):
		var by_interaction := reader.read_obj(d, "lines", path)
		for interaction_id: Variant in by_interaction:
			var ctx := "%s: lines for '%s'" % [path, interaction_id]
			var def := db.interaction(String(interaction_id))
			if def == null or def.target != "person":
				reader.error("%s: not a person-targeted interaction" % ctx)
				continue
			var by_outcome := reader.read_obj(by_interaction, String(interaction_id), ctx)
			var out: Dictionary = {}
			for outcome_id: Variant in by_outcome:
				if not SocialDef.OUTCOMES.has(String(outcome_id)):
					reader.error("%s: unknown outcome '%s'" % [ctx, outcome_id])
					continue
				var texts := reader.read_str_array(by_outcome, String(outcome_id), ctx)
				if texts.is_empty():
					reader.error("%s: no lines for '%s'" % [ctx, outcome_id])
				out[String(outcome_id)] = texts
			db.dialogue.lines[String(interaction_id)] = out
	if d.has("memories"):
		var by_kind := reader.read_obj(d, "memories", path)
		for kind: Variant in by_kind:
			db.dialogue.memories[String(kind)] = reader.read_str(by_kind, String(kind), path)
	if d.has("needs"):
		var by_need := reader.read_obj(d, "needs", path)
		for need_id: Variant in by_need:
			if db.need(String(need_id)) == null:
				reader.error("%s: unknown need '%s' in 'needs'" % [path, need_id])
				continue
			db.dialogue.needs[String(need_id)] = reader.read_str(by_need, String(need_id), path)
