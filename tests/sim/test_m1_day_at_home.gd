extends TestCase
## T-0016: M1's acceptance test. Proves the roadmap's "done when" for M1 (A Day at Home):
## with free will on, the player lives three game days in the flat with every need out of
## the red; saving and loading mid-action continues identically; and free will off (the
## contrast case) really does let a need fall.

const DAY_MINUTES: int = SimClock.MINUTES_PER_DAY
const THREE_DAYS: int = 3 * DAY_MINUTES
## No need may ever drop to or below this (NeedDef.critical_below is 15 for every need).
const NEVER_CRITICAL_AT: float = 15.0
## A need may be below this for at most 5% of sampled minutes.
const LOW_AT: float = 30.0
const LOW_MAX_FRACTION: float = 0.05
const MIN_DISTINCT_INTERACTIONS: int = 6


## min/avg/below-count per need id, sampled once per game minute.
func _new_need_stats(sim: Sim) -> Dictionary:
	var out: Dictionary = {}
	for need_def: NeedDef in sim.content.needs:
		var start: float = float(sim.world.player().needs.get(need_def.id, need_def.start))
		out[need_def.id] = {"min": start, "sum": 0.0, "count": 0, "below": 0}
	return out


func _sample_needs(sim: Sim, stats: Dictionary) -> void:
	var player := sim.world.player()
	for need_id: String in stats:
		var value: float = float(player.needs.get(need_id, 0.0))
		var entry: Dictionary = stats[need_id]
		entry["min"] = minf(float(entry["min"]), value)
		entry["sum"] = float(entry["sum"]) + value
		entry["count"] = int(entry["count"]) + 1
		if value < LOW_AT:
			entry["below"] = int(entry["below"]) + 1


## Drains events accumulated this minute, tallying the player's action_finished interactions.
func _count_finished(sim: Sim, counts: Dictionary) -> void:
	for event: Dictionary in sim.events.drain():
		if event["type"] != &"action_finished":
			continue
		if int(event["data"].get("person_id", -1)) != sim.world.player_id:
			continue
		var interaction_id := String(event["data"]["interaction_id"])
		counts[interaction_id] = int(counts.get(interaction_id, 0)) + 1


## Runs a fresh game for `minutes`, sampling needs and tallying finished interactions.
## Prints "seed N: <need> min .. avg .. below30 ..%" lines for the review, as the ticket asks.
func _run_and_report(seed_value: int, minutes: int) -> Dictionary:
	var sim := SimFactory.new_game(content(), seed_value)
	var stats := _new_need_stats(sim)
	var finished: Dictionary = {}
	for m: int in minutes:
		sim.run_minutes(1)
		_sample_needs(sim, stats)
		_count_finished(sim, finished)
	for need_id: String in stats:
		var entry: Dictionary = stats[need_id]
		var count: int = int(entry["count"])
		var avg: float = float(entry["sum"]) / count if count > 0 else 0.0
		print("    seed %d: %-8s min %.1f  avg %.1f  below 30: %.1f%% of minutes" % [
			seed_value, need_id, float(entry["min"]), avg, 100.0 * int(entry["below"]) / float(count)])
	return {"stats": stats, "finished": finished}


func test_three_days_three_seeds_keep_every_need_out_of_the_red() -> void:
	for seed_value: int in [1, 2, 3]:
		var result := _run_and_report(seed_value, THREE_DAYS)
		var stats: Dictionary = result["stats"]
		var finished: Dictionary = result["finished"]
		for need_id: String in stats:
			var entry: Dictionary = stats[need_id]
			var count: int = int(entry["count"])
			var below_fraction: float = int(entry["below"]) / float(count)
			assert_true(float(entry["min"]) >= NEVER_CRITICAL_AT,
				"seed %d: %s dropped to %.1f (never below %.1f)" % [seed_value, need_id, float(entry["min"]), NEVER_CRITICAL_AT])
			assert_true(below_fraction <= LOW_MAX_FRACTION,
				"seed %d: %s was below 30 for %.1f%% of minutes (max 5%%)" % [seed_value, need_id, 100.0 * below_fraction])
		assert_true(finished.size() >= MIN_DISTINCT_INTERACTIONS,
			"seed %d: only %d distinct interactions finished (%s)" % [seed_value, finished.size(), finished])


## True once the player's front action is "sleep" and it has started PERFORMING.
func _is_performing_sleep(sim: Sim) -> bool:
	var player := sim.world.player()
	if player.action_queue.is_empty():
		return false
	var action: Action = player.action_queue[0]
	return action.interaction_id == "sleep" and action.state == Action.PERFORMING


func test_save_mid_sleep_and_continue_equals_an_uninterrupted_run() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var minutes_to_sleep := 0
	while not _is_performing_sleep(sim) and minutes_to_sleep < 2 * DAY_MINUTES:
		sim.run_minutes(1)
		minutes_to_sleep += 1
	assert_true(_is_performing_sleep(sim), "the player never started sleeping within 2 days")
	if not _is_performing_sleep(sim):
		return

	var total_minutes := minutes_to_sleep + 600
	var errors: Array[String] = []
	var resumed := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(resumed != null, "load failed: %s" % [errors])
	if resumed == null:
		return
	resumed.run_minutes(600)

	var straight := SimFactory.new_game(content(), 1)
	straight.run_minutes(total_minutes)

	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_free_will_off_leaves_the_player_idle_and_a_need_falls() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	sim.submit(SetFreeWillCommand.new(player.id, false))
	var stats := _new_need_stats(sim)
	for m: int in DAY_MINUTES:
		sim.run_minutes(1)
		assert_true(player.action_queue.is_empty(), "the player should never act with free will off (minute %d)" % m)
		_sample_needs(sim, stats)
	var any_below := false
	for need_id: String in stats:
		if float(stats[need_id]["min"]) < LOW_AT:
			any_below = true
	assert_true(any_below, "with free will off for a day, at least one need should fall below 30")
