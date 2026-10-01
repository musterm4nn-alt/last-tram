class_name Replay
extends RefCounted
## Replays a stretch of play: a start save, then every command applied since (with its
## tick), up to an end tick; and compares the result with an end save. This is the core of
## F9 bug reports (T-0024): same start + same commands = the same end, bit for bit
## (docs/architecture.md → Determinism). Pure: no files (tools/replay_files.gd reads them).
##
## A save stores commands that were queued but not applied yet ("pending_commands"). The
## game logs them when it applies them, like any other command, so a replay empties the
## start save's pending commands and submits every logged command at its tick instead;
## otherwise they would run twice.


## Loads `start` without its pending commands, then steps until clock.tick == end_tick,
## submitting each logged command (in log order) just before the step whose starting tick
## equals the entry's "tick". Returns null (and fills `errors`) if the start does not load,
## an entry is malformed or has an unknown command type, or an entry's tick is before the
## start tick, not before end_tick, or earlier than the entry before it.
static func run(start: Dictionary, commands: Array, end_tick: int, content: ContentDB,
		errors: Array[String] = []) -> Sim:
	var data := start.duplicate(true)
	data["pending_commands"] = []
	var sim := SaveCodec.from_dict(data, content, errors)
	if sim == null:
		return null
	var start_tick := sim.clock.tick
	if end_tick < start_tick:
		errors.append("The end (tick %d) is before the start (tick %d)." % [end_tick, start_tick])
		return null
	var ticks: Array[int] = []
	var decoded: Array[Command] = []
	for entry: Variant in commands:
		if not entry is Dictionary or not (entry as Dictionary).has("tick") or not (entry as Dictionary).get("command") is Dictionary:
			errors.append("A command log entry is not {\"tick\", \"command\"}: %s" % [entry])
			return null
		var tick := int(entry["tick"])
		if tick < start_tick or tick >= end_tick:
			errors.append("A command at tick %d is outside the replay (ticks %d to %d)." % [tick, start_tick, end_tick])
			return null
		if not ticks.is_empty() and tick < ticks[ticks.size() - 1]:
			errors.append("The command log is out of order at tick %d." % tick)
			return null
		var command := CommandRegistry.decode(entry["command"])
		if command == null:
			errors.append("Unknown command type '%s' at tick %d." % [(entry["command"] as Dictionary).get("type", ""), tick])
			return null
		ticks.append(tick)
		decoded.append(command)
	var next := 0
	while sim.clock.tick < end_tick:
		while next < decoded.size() and ticks[next] == sim.clock.tick:
			sim.submit(decoded[next])
			next += 1
		sim.step()
	return sim


## "" if `expected` and `actual` are equal; otherwise the path and both values of the first
## difference, e.g. 'world.people[0].pos[0]: expected 12.5, got 12.75'. Dictionaries compare
## sorted keys (a missing key is a difference), arrays their length first, then items in
## order; numbers compare exactly (determinism means bit-identical).
static func first_difference(expected: Variant, actual: Variant, path: String = "") -> String:
	var here := path if not path.is_empty() else "(the save)"
	if expected is Dictionary and actual is Dictionary:
		var keys: Array = (expected as Dictionary).keys()
		for key: Variant in (actual as Dictionary).keys():
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key: Variant in keys:
			var child := String(key) if path.is_empty() else "%s.%s" % [path, key]
			if not (expected as Dictionary).has(key):
				return "%s: expected nothing, got %s" % [child, _show((actual as Dictionary)[key])]
			if not (actual as Dictionary).has(key):
				return "%s: expected %s, got nothing" % [child, _show((expected as Dictionary)[key])]
			var found := first_difference((expected as Dictionary)[key], (actual as Dictionary)[key], child)
			if not found.is_empty():
				return found
		return ""
	if expected is Array and actual is Array:
		var a: Array = expected
		var b: Array = actual
		if a.size() != b.size():
			return "%s: expected %d items, got %d" % [here, a.size(), b.size()]
		for index: int in a.size():
			var found := first_difference(a[index], b[index], "%s[%d]" % [path, index])
			if not found.is_empty():
				return found
		return ""
	if typeof(expected) != typeof(actual) or expected != actual:
		return "%s: expected %s, got %s" % [here, _show(expected), _show(actual)]
	return ""


## Replays and compares with `end`, ignoring "pending_commands" on both sides. "" when the
## replay reproduces the end save, otherwise a message (a load error, or first_difference()).
static func check(start: Dictionary, commands: Array, end: Dictionary, content: ContentDB) -> String:
	var errors: Array[String] = []
	var sim := run(start, commands, end_tick_of(end), content, errors)
	if sim == null:
		return "; ".join(errors)
	return compare(sim, end)


## The first difference between `sim` and the save dictionary `end`, both round-tripped
## through JSON so numbers compare the same way; "pending_commands" is ignored.
static func compare(sim: Sim, end: Dictionary) -> String:
	var replayed: Dictionary = Ser.restore_floats(JSON.parse_string(Ser.to_json(SaveCodec.to_dict(sim))))
	var expected: Dictionary = Ser.restore_floats(JSON.parse_string(Ser.to_json(end)))
	replayed.erase("pending_commands")
	expected.erase("pending_commands")
	return first_difference(expected, replayed)


## The clock tick of a save dictionary (-1 when it has none).
static func end_tick_of(save: Dictionary) -> int:
	var clock: Variant = save.get("clock")
	if clock is Dictionary and (clock as Dictionary).has("tick"):
		return int((clock as Dictionary)["tick"])
	return -1


static func _show(value: Variant) -> String:
	if value is String:
		return "\"%s\"" % value
	return JSON.stringify(value, "", true, true)
