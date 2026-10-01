class_name SocialLoader
extends RefCounted
## Reads and validates the "social" block of a person-targeted interaction (T-0038):
##   "social": {"kind": "friendly", "base": 1.5,
##     "success": {"actor": {"friendship": 2}, "target": {"friendship": 2},
##                 "actor_moodlet": "", "target_moodlet": "good_talk",
##                 "target_needs": {"social": 4}, "memory": "chatted", "valence": 10},
##     "fail": {...}}


static func read(db: ContentDB, reader: ContentReader, d: Dictionary, ctx: String) -> SocialDef:
	var block := reader.read_obj(d, "social", ctx)
	var social := SocialDef.new()
	var sctx := ctx + " social"
	social.kind = reader.read_str(block, "kind", sctx)
	if not SocialDef.KINDS.has(social.kind):
		reader.error("%s: 'kind' must be one of %s" % [sctx, ", ".join(SocialDef.KINDS)])
	social.base = reader.read_num(block, "base", sctx)
	for outcome_id: String in SocialDef.OUTCOMES:
		var o := reader.read_obj(block, outcome_id, sctx)
		var octx := "%s %s" % [sctx, outcome_id]
		var outcome := SocialOutcomeDef.new()
		outcome.actor = _deltas(reader, o, "actor", octx)
		outcome.target = _deltas(reader, o, "target", octx)
		outcome.actor_moodlet = _moodlet(db, reader, o, "actor_moodlet", octx)
		outcome.target_moodlet = _moodlet(db, reader, o, "target_moodlet", octx)
		for need_id: Variant in reader.read_obj(o, "target_needs", octx):
			if db.need(String(need_id)) == null:
				reader.error("%s: unknown need '%s' in 'target_needs'" % [octx, need_id])
				continue
			outcome.target_needs[String(need_id)] = float((o["target_needs"] as Dictionary)[need_id])
		outcome.memory = reader.read_str(o, "memory", octx)
		outcome.valence = reader.read_int(o, "valence", octx)
		if outcome.valence < -100 or outcome.valence > 100:
			reader.error("%s: 'valence' must be within -100..100" % octx)
		social.outcomes[outcome_id] = outcome
	return social


static func _deltas(reader: ContentReader, o: Dictionary, key: String, ctx: String) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	var raw := reader.read_obj(o, key, ctx)
	for name: Variant in raw:
		if not Relationship.RANGES.has(String(name)):
			reader.error("%s: '%s' is not a relationship value (%s)" % [ctx, name, ", ".join(Relationship.RANGES.keys())])
			continue
		var amount: Variant = raw[name]
		if not (amount is float or amount is int):
			reader.error("%s: '%s' must be a number" % [ctx, name])
			continue
		out[String(name)] = float(amount)
	return out


static func _moodlet(db: ContentDB, reader: ContentReader, o: Dictionary, key: String, ctx: String) -> String:
	var id := reader.read_str(o, key, ctx)
	if not id.is_empty() and db.moodlet(id) == null:
		reader.error("%s: unknown moodlet '%s' in '%s'" % [ctx, id, key])
	return id
