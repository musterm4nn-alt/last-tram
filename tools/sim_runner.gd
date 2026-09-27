extends SceneTree
## Runs the simulation headless and prints a report: a quick way to see what the town does
## over hours or days without graphics, and how fast the sim runs.
##   tools/simrun.sh --days=1 --seed=1
##   tools/simrun.sh --minutes=90 --walk=1,0 --report-every=10
## Options: --seed=N, --days=N, --minutes=N, --report-every=MINUTES (default 60),
##          --walk=X,Y (player holds a walking direction).
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
	var minutes := int(args.get("minutes", "0")) + int(args.get("days", "0")) * SimClock.MINUTES_PER_DAY
	if minutes <= 0:
		minutes = 60
	var report_every := maxi(1, int(args.get("report-every", "60")))
	if args.has("walk"):
		var parts := String(args["walk"]).split(",")
		sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2(parts[0].to_float(), parts[1].to_float())))

	print("Simulating %d game minutes (seed %s)" % [minutes, args.get("seed", "1")])
	_report(sim)
	var started := Time.get_ticks_usec()
	for m: int in minutes:
		sim.run_minutes(1)
		if (m + 1) % report_every == 0:
			_report(sim)
	var seconds := (Time.get_ticks_usec() - started) / 1_000_000.0
	var steps := minutes * SimClock.STEPS_PER_GAME_MINUTE
	print("Done: %d steps in %.2f s (%.4f ms per step)" % [
		steps, seconds, seconds * 1000.0 / steps])
	print("LAST_TRAM_SIMRUN: OK")
	quit(0)


func _report(sim: Sim) -> void:
	var player := sim.world.player()
	var place: PlaceDef = sim.content.place_at(player.cell())
	var need_parts: PackedStringArray = []
	for need_def: NeedDef in sim.content.needs:
		need_parts.append("%s=%.1f" % [need_def.id, float(player.needs.get(need_def.id, need_def.start))])
	print("[%s] people %d | player (%.1f, %.1f) %s | needs %s | mood %.1f (%s)" % [
		sim.clock.format(), sim.world.people.size(), player.pos.x, player.pos.y,
		place.name if place != null else "-", " ".join(need_parts),
		Mood.compute(player, sim.content), Mood.label(Mood.compute(player, sim.content))])


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
