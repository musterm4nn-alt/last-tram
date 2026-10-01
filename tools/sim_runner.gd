extends SceneTree
## Runs the simulation headless and prints a report: a quick way to see what the town does
## over hours or days without graphics, and how fast the sim runs.
##   tools/simrun.sh --days=1 --seed=1
##   tools/simrun.sh --minutes=90 --walk=1,0 --report-every=10
##   tools/simrun.sh --days=1 --no-free-will
## Options: --seed=N, --days=N, --minutes=N, --report-every=MINUTES (default 60),
##          --walk=X,Y (player holds a walking direction),
##          --no-free-will (turns the player's free will off at the start, so needs are
##          not looked after; useful to contrast with the default run for M1's acceptance).
## The summary covers the player and, separately, all residents together (T-0035).
## As systems are added, extend _report() with their key numbers (needs, money, crimes...).


func _initialize() -> void:
	var args := _parse_args()
	var content := ContentDB.load_default()
	if not content.is_valid():
		print("Content errors:\n  " + "\n  ".join(content.errors))
		print("LAST_TRAM_SIMRUN: FAILED")
		quit(1)
		return
	var sim := SimFactory.new_game(content, int(args.get("seed", "1")))
	if args.has("no-free-will"):
		sim.submit(SetFreeWillCommand.new(sim.world.player_id, false))
	var minutes := int(args.get("minutes", "0")) + int(args.get("days", "0")) * SimClock.MINUTES_PER_DAY
	if minutes <= 0:
		minutes = 60
	var report_every := maxi(1, int(args.get("report-every", "60")))
	if args.has("walk"):
		var parts := String(args["walk"]).split(",")
		sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2(parts[0].to_float(), parts[1].to_float())))

	print("Simulating %d game minutes (seed %s)" % [minutes, args.get("seed", "1")])
	_report(sim)
	var need_stats := _new_need_stats(sim)
	var resident_stats := _new_need_stats(sim)
	var action_counts: Dictionary = {}
	var resident_actions: Dictionary = {}
	var started := Time.get_ticks_usec()
	for m: int in minutes:
		sim.run_minutes(1)
		_sample_needs(sim, need_stats)
		_sample_residents(sim, resident_stats)
		_count_finished_actions(sim, action_counts, resident_actions)
		if (m + 1) % report_every == 0:
			_report(sim)
	var seconds := (Time.get_ticks_usec() - started) / 1_000_000.0
	var steps := minutes * SimClock.STEPS_PER_GAME_MINUTE
	print("Done: %d steps in %.2f s (%.4f ms per step)" % [
		steps, seconds, seconds * 1000.0 / steps])
	_report_need_stats(sim, need_stats, minutes)
	_report_action_counts(action_counts)
	var residents := sim.world.people.size() - 1
	if residents > 0:
		print("residents (%d), over all their minutes:" % residents)
		_report_need_stats(sim, resident_stats, minutes)
		_report_action_counts(resident_actions, "resident actions")
	print("LAST_TRAM_SIMRUN: OK")
	quit(0)


func _report(sim: Sim) -> void:
	var player := sim.world.player()
	var place: PlaceDef = sim.content.place_at(player.cell())
	var need_parts: PackedStringArray = []
	for need_def: NeedDef in sim.content.needs:
		need_parts.append("%s=%.1f" % [need_def.id, float(player.needs.get(need_def.id, need_def.start))])
	var asleep := 0
	for person: Person in sim.world.people.values():
		if not person.action_queue.is_empty() and person.action_queue[0].state == Action.PERFORMING:
			var def := sim.content.interaction(person.action_queue[0].interaction_id)
			if def != null and def.routine == "sleep":
				asleep += 1
	print("[%s] people %d (%d asleep) | player (%.1f, %.1f) %s | needs %s | mood %.1f (%s)" % [
		sim.clock.format(), sim.world.people.size(), asleep, player.pos.x, player.pos.y,
		place.name if place != null else "-", " ".join(need_parts),
		Mood.compute(player, sim.content), Mood.label(Mood.compute(player, sim.content))])


## One {"min": float, "sum": float, "count": int, "below_30": int} entry per need id.
func _new_need_stats(sim: Sim) -> Dictionary:
	var out: Dictionary = {}
	for need_def: NeedDef in sim.content.needs:
		var start: float = float(sim.world.player().needs.get(need_def.id, need_def.start))
		out[need_def.id] = {"min": start, "sum": 0.0, "count": 0, "below_30": 0}
	return out


## Samples the player's needs into `stats`, called once per game minute.
func _sample_needs(sim: Sim, stats: Dictionary) -> void:
	var player := sim.world.player()
	for need_id: String in stats:
		var value: float = float(player.needs.get(need_id, 0.0))
		var entry: Dictionary = stats[need_id]
		entry["min"] = minf(float(entry["min"]), value)
		entry["sum"] = float(entry["sum"]) + value
		entry["count"] = int(entry["count"]) + 1
		if value < 30.0:
			entry["below_30"] = int(entry["below_30"]) + 1


## Samples every resident's needs into `stats` (one sample per resident per minute).
func _sample_residents(sim: Sim, stats: Dictionary) -> void:
	for person: Person in sim.world.people.values():
		if person.id == sim.world.player_id:
			continue
		for need_id: String in stats:
			var value: float = float(person.needs.get(need_id, 0.0))
			var entry: Dictionary = stats[need_id]
			entry["min"] = minf(float(entry["min"]), value)
			entry["sum"] = float(entry["sum"]) + value
			entry["count"] = int(entry["count"]) + 1
			if value < 30.0:
				entry["below_30"] = int(entry["below_30"]) + 1


## Drains this minute's events and tallies finished interactions: the player's in `counts`,
## everyone else's in `resident_counts`.
func _count_finished_actions(sim: Sim, counts: Dictionary, resident_counts: Dictionary) -> void:
	for event: Dictionary in sim.events.drain():
		if event["type"] != &"action_finished":
			continue
		var data: Dictionary = event["data"]
		var target := counts if int(data.get("person_id", -1)) == sim.world.player_id else resident_counts
		var interaction_id := String(data["interaction_id"])
		target[interaction_id] = int(target.get(interaction_id, 0)) + 1


func _report_need_stats(sim: Sim, stats: Dictionary, minutes: int) -> void:
	for need_def: NeedDef in sim.content.needs:
		var entry: Dictionary = stats[need_def.id]
		var count: int = int(entry["count"])
		var avg: float = float(entry["sum"]) / count if count > 0 else 0.0
		var below_pct: float = 100.0 * float(entry["below_30"]) / count if count > 0 else 0.0
		print("%-8s min %.1f  avg %.1f  below 30: %.1f%% of minutes" % [
			need_def.id, float(entry["min"]), avg, below_pct])


func _report_action_counts(counts: Dictionary, label: String = "actions") -> void:
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		if int(counts[a]) != int(counts[b]):
			return int(counts[a]) > int(counts[b])
		return a < b)
	var parts: PackedStringArray = []
	for id: String in ids:
		parts.append("%s %d" % [id, int(counts[id])])
	print("%s: %s" % [label, ", ".join(parts) if not parts.is_empty() else "none"])


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var eq := arg.find("=")
			if eq < 0:
				out[arg.substr(2)] = ""
			else:
				out[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
	return out
