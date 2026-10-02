class_name DiscoveryLoader
extends RefCounted
## Loads every .json file in data/discoveries/ into ContentDB.discoveries (T-0067). Runs
## after the world, interactions, moodlets and scenes, which it checks against. A missing
## folder means no discoveries. Each file: {"discoveries": [{"id", "name", "clue",
## "place_id", "from": "HH:MM", "to": "HH:MM", "level", "clue_required", "share_trust",
## "effects": [{"kind": ..., ...}], "scene"?}]}.


static func load(db: ContentDB, reader: ContentReader, dir: String) -> void:
	var listing := DirAccess.open(dir)
	if listing != null:
		var files := listing.get_files()
		files.sort()
		for file: String in files:
			if file.get_extension() == "json":
				load_file(db, reader, dir.path_join(file))
	check_links(db, reader)


static func load_file(db: ContentDB, reader: ContentReader, path: String) -> void:
	var root: Variant = reader.read_json(path)
	if not root is Dictionary:
		return
	for entry: Variant in reader.read_arr(root, "discoveries", path):
		if not entry is Dictionary:
			reader.error("%s: every discovery must be an object" % path)
			continue
		var d: Dictionary = entry
		var def := DiscoveryDef.new()
		def.id = reader.read_str(d, "id", path)
		var ctx := "%s: discovery '%s'" % [path, def.id]
		def.name = reader.read_str(d, "name", ctx)
		def.clue = reader.read_str(d, "clue", ctx)
		def.place_id = reader.read_str(d, "place_id", ctx)
		def.from_minute = _minute(reader, d, "from", ctx)
		def.to_minute = _minute(reader, d, "to", ctx)
		def.level = reader.read_int(d, "level", ctx)
		def.clue_required = reader.read_bool(d, "clue_required", ctx)
		def.share_trust = reader.read_int(d, "share_trust", ctx)
		if d.has("known_at_start"):
			def.known_at_start = reader.read_str(d, "known_at_start", ctx)
			if db.place(def.known_at_start) == null:
				reader.error("%s: unknown place '%s' in 'known_at_start'" % [ctx, def.known_at_start])
		if d.has("scene"):
			def.scene_id = reader.read_str(d, "scene", ctx)
			if not db.scenes.has(def.scene_id):
				reader.error("%s: unknown scene '%s'" % [ctx, def.scene_id])
		var place := db.place(def.place_id)
		if place == null:
			reader.error("%s: unknown place '%s'" % [ctx, def.place_id])
		elif place.level != def.level:
			reader.error("%s: 'level' %d is not the level of '%s'" % [ctx, def.level, def.place_id])
		if def.share_trust < -1 or def.share_trust > 100:
			reader.error("%s: 'share_trust' must be -1 (never shared) or 0..100" % ctx)
		for effect_entry: Variant in reader.read_arr(d, "effects", ctx):
			var effect := _effect(db, reader, effect_entry, ctx)
			if effect != null:
				def.effects.append(effect)
		if def.id.is_empty() or db.discoveries.has(def.id):
			reader.error("%s: empty or duplicate discovery id" % ctx)
			continue
		db.discoveries[def.id] = def


## "HH:MM" as a minute of the day.
static func _minute(reader: ContentReader, d: Dictionary, key: String, ctx: String) -> int:
	var text := reader.read_str(d, key, ctx)
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() \
			or int(parts[0]) < 0 or int(parts[0]) > 23 or int(parts[1]) < 0 or int(parts[1]) > 59:
		reader.error("%s: '%s' must be a time \"HH:MM\"" % [ctx, key])
		return 0
	return int(parts[0]) * 60 + int(parts[1])


static func _effect(db: ContentDB, reader: ContentReader, entry: Variant, ctx: String) -> DiscoveryEffect:
	if not entry is Dictionary:
		reader.error("%s: every effect must be an object" % ctx)
		return null
	var d: Dictionary = entry
	var effect := DiscoveryEffect.new()
	effect.kind = reader.read_str(d, "kind", ctx)
	match effect.kind:
		DiscoveryEffect.NOTE:
			effect.text = reader.read_str(d, "text", ctx)
		DiscoveryEffect.MONEY:
			effect.cents = reader.read_int(d, "cents", ctx)
			if effect.cents <= 0:
				reader.error("%s: a money effect needs 'cents' > 0" % ctx)
		DiscoveryEffect.MOODLET:
			effect.moodlet_id = reader.read_str(d, "moodlet", ctx)
			if db.moodlet(effect.moodlet_id) == null:
				reader.error("%s: unknown moodlet '%s'" % [ctx, effect.moodlet_id])
		DiscoveryEffect.CONTACT:
			effect.place_id = reader.read_str(d, "place_id", ctx)
			if db.place(effect.place_id) == null:
				reader.error("%s: unknown contact place '%s'" % [ctx, effect.place_id])
		DiscoveryEffect.UNLOCK:
			effect.interaction_id = reader.read_str(d, "interaction", ctx)
		DiscoveryEffect.CLUE:
			effect.discovery_id = reader.read_str(d, "discovery", ctx)
		_:
			reader.error("%s: unknown effect kind '%s' (one of %s)" % [ctx, effect.kind, ", ".join(DiscoveryEffect.KINDS)])
			return null
	return effect


## Cross-checks once everything is loaded: interactions name real discoveries; an unlock
## effect names an interaction that requires that discovery; a discovery that needs its clue
## has a way to learn it (someone shares it, an interaction teaches it, another discovery
## leads to it, or people know it from the start).
static func check_links(db: ContentDB, reader: ContentReader) -> void:
	var taught: Dictionary[String, bool] = {}
	for interaction: InteractionDef in db.interactions.values():
		for key: String in ["requires_discovery", "teaches_clue"]:
			var id := String(interaction.get(key))
			if not id.is_empty() and not db.discoveries.has(id):
				reader.error("interaction '%s': unknown discovery '%s' in '%s'" % [interaction.id, id, key])
		if not interaction.teaches_clue.is_empty():
			taught[interaction.teaches_clue] = true
		for place_id: String in interaction.places:
			if db.place(place_id) == null:
				reader.error("interaction '%s': unknown place '%s' in 'places'" % [interaction.id, place_id])
	for def: DiscoveryDef in db.discoveries.values():
		var leads_here := false
		for other: DiscoveryDef in db.discoveries.values():
			leads_here = leads_here or other.effects.any(func(e: DiscoveryEffect) -> bool: return e.kind == DiscoveryEffect.CLUE and e.discovery_id == def.id)
		for effect: DiscoveryEffect in def.effects:
			if effect.kind == DiscoveryEffect.CLUE and not db.discoveries.has(effect.discovery_id):
				reader.error("discovery '%s': unknown discovery '%s' in a clue effect" % [def.id, effect.discovery_id])
			if effect.kind != DiscoveryEffect.UNLOCK:
				continue
			var interaction := db.interaction(effect.interaction_id)
			if interaction == null or interaction.requires_discovery != def.id:
				reader.error("discovery '%s': unlock_interaction '%s' must be an interaction with requires_discovery '%s'" % [def.id, effect.interaction_id, def.id])
		if def.clue_required and def.share_trust < 0 and not taught.has(def.id) and not leads_here and def.known_at_start.is_empty():
			reader.error("discovery '%s': needs its clue, but nobody shares it and nothing teaches it" % def.id)
