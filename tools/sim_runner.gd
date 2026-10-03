extends SceneTree
## Runs the simulation headless and prints a report: a quick way to see what the town does
## over hours or days without graphics, and how fast the sim runs.
##   tools/simrun.sh --days=1 --seed=1
##   tools/simrun.sh --minutes=90 --walk=1,0 --report-every=10
##   tools/simrun.sh --days=1 --no-free-will
## Options: --seed=N, --days=N, --minutes=N, --report-every=MINUTES (default 60),
##          --walk=X,Y (player holds a walking direction),
##          --no-free-will (turns the player's free will off at the start, so needs are
##          not looked after; useful to contrast with the default run for M1's acceptance),
##          --tiers=full|tiered and --active-radius=CELLS (the fidelity dial, T-0042; the
##          demote radius is 10 cells more), --gentle-work (every job uses the gentle need
##          profile instead of its own, T-0077), --check-m2 (M2 acceptance, T-0045: fails the run
##          unless the town lives well, see TownCheck, and the cost stays within
##          BUDGET_MS_PER_STEP), --check-staffing (T-0065: fails the run unless every shop
##          had someone serving for TownCheck.MIN_STAFFED_SHARE of its open time),
##          --check-m3 (M3 acceptance, T-0076: run it with --days=30; fails the run unless the
##          economy stays stable, see EconomyCheck, the town passes the M2 rules and the cost
##          stays within BUDGET_MS_PER_STEP),
##          --profile (T-0078: time per system, in ms per step), --extra-residents=N (a stress
##          test: N more adults move into the existing homes, round-robin; beds run short, so
##          only use it to measure cost).

## The M2 cost budget: milliseconds of sim work per step, with ~30 people.
const BUDGET_MS_PER_STEP: float = 0.25
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
	if args.has("tiers"):
		sim.world.tiers.mode = String(args["tiers"])
	if args.has("active-radius"):
		sim.world.tiers.active_radius = float(args["active-radius"])
		sim.world.tiers.demote_radius = sim.world.tiers.active_radius + 10.0
	if args.has("gentle-work"):
		sim.world.work.gentle = true
	if args.has("extra-residents"):
		_add_residents(sim, int(args["extra-residents"]))
	var profiled: Array[ProfiledSystem] = []
	if args.has("profile"):
		for i: int in sim.systems.size():
			var wrapped := ProfiledSystem.new(sim.systems[i])
			profiled.append(wrapped)
			sim.systems[i] = wrapped
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
	var town := TownCheck.new()
	var economy := EconomyCheck.new()
	economy.start(sim)
	var started := Time.get_ticks_usec()
	for m: int in minutes:
		sim.run_minutes(1)
		_sample_needs(sim, need_stats)
		_sample_residents(sim, resident_stats)
		_count_finished_actions(sim, action_counts, resident_actions, town, economy)
		town.sample(sim)
		if sim.clock.minute_of_day() == 0:
			economy.end_of_day(sim)
		if (m + 1) % report_every == 0:
			_report(sim)
	var seconds := (Time.get_ticks_usec() - started) / 1_000_000.0
	var steps := minutes * SimClock.STEPS_PER_GAME_MINUTE
	print("Done: %d steps in %.2f s (%.4f ms per step)" % [
		steps, seconds, seconds * 1000.0 / steps])
	for wrapped: ProfiledSystem in profiled:
		print("profile %-15s %.4f ms per step" % [wrapped.name, wrapped.usec / 1000.0 / steps])
	_report_need_stats(sim, need_stats, minutes)
	_report_action_counts(action_counts)
	var residents := sim.world.people.size() - 1
	if residents > 0:
		print("residents (%d), over all their minutes:" % residents)
		_report_need_stats(sim, resident_stats, minutes)
		_report_action_counts(resident_actions, "resident actions")
	for line: String in town.summary(sim):
		print(line)
	print(_money_line(sim))
	print(_groceries_line(sim, resident_actions))
	print(_jobs_line(sim))
	print(town.work_summary())
	print(_housing_line(sim))
	print(town.staffing_summary(sim))
	print(economy.summary())
	var ms_per_step := seconds * 1000.0 / steps
	if args.has("check-staffing") and not _passes("STAFFING CHECK", town.staffing_failures(sim)):
		return
	if args.has("check-m2"):
		var problems := town.failures(sim, minutes / SimClock.MINUTES_PER_DAY)
		problems.append_array(_budget_problems(ms_per_step))
		if not _passes("M2 CHECK", problems):
			return
	if args.has("check-m3"):
		var problems := economy.failures(sim, town)
		problems.append_array(town.failures(sim, minutes / SimClock.MINUTES_PER_DAY))
		problems.append_array(_budget_problems(ms_per_step))
		if not _passes("M3 CHECK", problems):
			return
	print("LAST_TRAM_SIMRUN: OK")
	quit(0)


## Prints a check's problems and its verdict; on failure, also fails the run (and quits).
func _passes(label: String, problems: PackedStringArray) -> bool:
	for problem: String in problems:
		print("%s: %s" % [label, problem])
	print("%s: %s" % [label, "PASSED" if problems.is_empty() else "FAILED"])
	if not problems.is_empty():
		print("LAST_TRAM_SIMRUN: FAILED")
		quit(1)
	return problems.is_empty()


## [] within BUDGET_MS_PER_STEP, else the overrun in words.
func _budget_problems(ms_per_step: float) -> PackedStringArray:
	if ms_per_step <= BUDGET_MS_PER_STEP:
		return PackedStringArray()
	return PackedStringArray(["%.3f ms per step is over the %.2f ms budget" % [ms_per_step, BUDGET_MS_PER_STEP]])


## Stress test (T-0078): `count` more adults join existing households, round-robin by id,
## spawned in their homes with a job draw like new towns (money and wardrobes too).
func _add_residents(sim: Sim, count: int) -> void:
	var rng := sim.rng.stream("stress")
	var households: Array = sim.world.households.keys()
	households.sort()
	households.erase(sim.world.player().household_id)
	for i: int in count:
		var household: Household = sim.world.households[households[i % households.size()]]
		var lot: Lot = sim.world.lots.get(household.home_lot_id)
		var cells := Lots.free_cells(sim, sim.content.place(lot.place_id)) if lot != null else []
		if cells.is_empty():
			continue
		var person := SimFactory.spawn_person(sim, cells[rng.randi_range(0, cells.size() - 1)], CharacterSpec.random(sim.content, rng))
		person.household_id = household.id
		person.home_lot_id = household.home_lot_id
		person.benefit_registered = true
		household.member_ids.append(person.id)
		Money.give_resident_start(sim, person, rng)
		Wardrobe.give_person_start(sim, person, rng)
	print("stress: %d people" % sim.world.people.size())


func _report(sim: Sim) -> void:
	var player := sim.world.player()
	var place: PlaceDef = sim.content.place_at(player.cell())
	var need_parts: PackedStringArray = []
	for need_def: NeedDef in sim.content.needs:
		need_parts.append("%s=%.1f" % [need_def.id, float(player.needs.get(need_def.id, need_def.start))])
	var asleep := 0
	var background := 0
	for person: Person in sim.world.people.values():
		if person.background:
			background += 1
		if not person.action_queue.is_empty() and person.action_queue[0].state == Action.PERFORMING:
			var def := sim.content.interaction(person.action_queue[0].interaction_id)
			if def != null and def.routine == "sleep":
				asleep += 1
	print("[%s] people %d (%d asleep, %d background) | player (%.1f, %.1f) %s | needs %s | mood %.1f (%s)" % [
		sim.clock.format(), sim.world.people.size(), asleep, background, player.pos.x, player.pos.y,
		place.name if place != null else "-", " ".join(need_parts),
		Mood.compute(player, sim.content), Mood.label(Mood.compute(player, sim.content))])


## "money: people hold €X (median €Y) | in: start €A, … | out: purchase €B, …".
func _money_line(sim: Sim) -> String:
	var amounts: Array[int] = []
	for person: Person in sim.world.people.values():
		amounts.append(person.wallet.total())
	amounts.sort()
	var median := amounts[amounts.size() / 2] if not amounts.is_empty() else 0
	return "money: people hold %s (median %s) | in: %s | out: %s" % [
		Money.format(Money.held(sim.world)), Money.format(median),
		_totals_text(sim.world.ledger.sources), _totals_text(sim.world.ledger.sinks)]


## "housing: N households behind on rent (owing €X in all), most weeks behind W".
func _housing_line(sim: Sim) -> String:
	var behind := 0
	var owed := 0
	var weeks := 0
	for lot: Lot in sim.world.lots.values():
		if lot.arrears > 0:
			behind += 1
			owed += lot.arrears
			weeks = maxi(weeks, lot.weeks_behind)
	return "housing: %d households behind on rent (owing %s in all), most weeks behind %d, %d homeless households, %d empty flats" % [
		behind, Money.format(owed), weeks, Moving.homeless(sim).size(), Moving.empty_homes(sim).size()]


## "jobs: 17 of 21 working-age residents employed, 6 retired, 4 vacancies".
func _jobs_line(sim: Sim) -> String:
	var working_age := 0
	var employed := 0
	var retired := 0
	for person: Person in sim.world.people.values():
		if person.id == sim.world.player_id:
			continue
		if person.age_years >= sim.content.economy.retirement_age:
			retired += 1
			continue
		working_age += 1
		if person.job != null:
			employed += 1
	return "jobs: %d of %d working-age residents employed, %d retired, %d vacancies" % [
		employed, working_age, retired, Jobs.vacancies(sim).size()]


## "groceries: households hold N portions (lowest M), bags bought K".
func _groceries_line(sim: Sim, resident_actions: Dictionary) -> String:
	var total := 0
	var lowest := -1
	for household: Household in sim.world.households.values():
		total += household.groceries
		lowest = household.groceries if lowest < 0 else mini(lowest, household.groceries)
	return "groceries: households hold %d portions (lowest %d), bags bought %d" % [
		total, maxi(lowest, 0), int(resident_actions.get("buy_groceries", 0))]


func _totals_text(totals: Dictionary[String, int]) -> String:
	var keys: Array = totals.keys()
	keys.sort()
	var parts: PackedStringArray = []
	for reason: String in keys:
		parts.append("%s %s" % [reason, Money.format(totals[reason])])
	return ", ".join(parts) if not parts.is_empty() else "none"


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
func _count_finished_actions(sim: Sim, counts: Dictionary, resident_counts: Dictionary, town: TownCheck, economy: EconomyCheck) -> void:
	for event: Dictionary in sim.events.drain():
		town.observe(sim, event)
		economy.observe(sim, event)
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
