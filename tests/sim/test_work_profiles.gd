extends TestCase
## T-0077: lunch at work is a real meal, jobs differ (or are all gentle, by a saved world
## setting), and the town check counts meals and colleagues honestly.

const MONDAY: int = 0


## A new game on Monday at `hour`; the player (an office clerk, free will off) stands on the
## tram shelter's first slot.
func _game(hour: int) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(MONDAY, hour)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	var shelter := Jobs.workplace(sim, player)
	var cell := shelter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.events.drain()
	return sim


func _start_work(sim: Sim) -> void:
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "work", Jobs.workplace(sim, player).id))
	sim.step()


func _of(events: Array[Dictionary], type: StringName, person_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["type"] == type and int(event["data"].get("person_id", -1)) == person_id:
			out.append(event["data"])
	return out


func test_lunch_at_work_is_a_meal() -> void:
	var sim := _game(9)
	var player := sim.world.player()
	assert_false(content().job("office_clerk").need_rates.has("hunger"), "hunger isn't a work rate any more")
	player.needs["hunger"] = 100.0
	_start_work(sim)
	var lunch_after := content().economy.lunch_after_minutes
	sim.run_minutes(lunch_after - 1)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", player.id).size(), 0, "not before lunchtime")
	player.needs["hunger"] = 20.0
	sim.run_minutes(1)
	var meals := _of(sim.events.drain(), &"meal_eaten", player.id)
	assert_eq(meals.size(), 1)
	if meals.size() == 1:
		assert_eq(meals[0]["kind"], "lunch")
	assert_near(float(player.needs["hunger"]), 20.0 + content().economy.lunch_hunger, 0.5, "fed like a meal")
	sim.run_minutes(8 * 60)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", player.id).size(), 0, "one lunch a shift")


func test_a_hungry_worker_takes_lunch_early() -> void:
	var sim := _game(9)
	var player := sim.world.player()
	player.needs["hunger"] = 100.0
	_start_work(sim)
	sim.run_minutes(30)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", player.id).size(), 0)
	player.needs["hunger"] = content().home_thresholds["eat_below"] - 1.0
	sim.run_minutes(1)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", player.id).size(), 1, "hungry: lunch now")
	sim.run_minutes(content().economy.lunch_after_minutes)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", player.id).size(), 0, "and not again at lunchtime")


func test_a_short_stint_has_no_lunch() -> void:
	var sim := _game(9)
	sim.world.player().needs["hunger"] = 100.0
	_start_work(sim)
	sim.run_minutes(content().economy.lunch_after_minutes - 30)
	sim.submit(CancelActionCommand.new(sim.world.player_id, 0))
	sim.run_minutes(60)
	assert_eq(_of(sim.events.drain(), &"meal_eaten", sim.world.player_id).size(), 0)


## The player's needs after an hour of work on Monday morning, starting from 50 each.
func _hour_of_work(gentle: bool) -> Dictionary:
	var sim := _game(9)
	sim.world.work.gentle = gentle
	var player := sim.world.player()
	for need_id: String in player.needs:
		player.needs[need_id] = 50.0
	_start_work(sim)
	sim.run_minutes(60)
	return player.needs.duplicate()


func test_varied_jobs_use_their_own_profile_and_gentle_ones_the_shared_one() -> void:
	var varied := _hour_of_work(false)
	var gentle := _hour_of_work(true)
	var comfort := content().need("comfort").decay_per_hour
	var fun := content().need("fun").decay_per_hour
	var desk := content().job("office_clerk").need_rates
	var shared := content().economy.gentle_profile
	assert_near(float(varied["comfort"]), 50.0 - comfort + desk["comfort"], 0.3, "a desk job is restful")
	assert_near(float(varied["fun"]), 50.0 - fun + desk["fun"], 0.3, "and boring")
	assert_near(float(gentle["comfort"]), 50.0 - comfort + shared["comfort"], 0.3)
	assert_near(float(gentle["fun"]), 50.0 - fun + shared["fun"], 0.3)
	assert_true(float(varied["fun"]) < float(gentle["fun"]), "the office is duller than the gentle profile")


func test_jobs_have_distinct_profiles() -> void:
	var seen: Dictionary[String, String] = {}
	for job: JobDef in content().jobs.values():
		var key := JSON.stringify(job.need_rates, "", true)
		if seen.has(key):
			assert_eq([seen[key], job.id], ["warehouse_worker", "builder"], "only the two manual jobs share a profile")
		seen[key] = job.id
	var office := content().job("office_clerk").need_rates
	var bar := content().job("bartender").need_rates
	var builder := content().job("builder").need_rates
	var spaeti := content().job("spaeti_clerk").need_rates
	assert_true(office["comfort"] > spaeti["comfort"], "standing is hard on comfort")
	assert_true(builder["energy"] < office["energy"] and builder["social"] > office["social"], "manual work: tiring but social")
	assert_true(bar["fun"] > office["fun"] and bar["energy"] < spaeti["energy"], "bar work: fun but exhausting")
	assert_eq(content().job("care_worker").shift_moodlet, "helped_someone", "care work is rewarding")


func test_care_work_gives_a_moodlet_only_when_varied() -> void:
	for gentle: bool in [false, true]:
		var sim := _game(9)
		sim.world.work.gentle = gentle
		var carer := sim.world.player()
		carer.job = Employment.new()
		carer.job.job_id = "care_worker"
		carer.job.shift_start = SimClock.ticks_for(MONDAY, 7)
		carer.job.shift_minutes = 8 * 60
		carer.moodlets.clear()
		Careers.settle(sim, carer)
		var helped := carer.moodlets.any(func(m: Moodlet) -> bool: return m.id == "helped_someone")
		assert_eq(helped, not gentle, "gentle %s" % gentle)


func test_the_gentle_setting_is_a_command_and_is_saved() -> void:
	var sim := _game(9)
	assert_false(sim.world.work.gentle, "varied by default")
	sim.submit(SetGentleWorkCommand.new(true))
	sim.step()
	assert_true(sim.world.work.gentle)
	var encoded := CommandRegistry.encode(SetGentleWorkCommand.new(true))
	var decoded := CommandRegistry.decode(encoded) as SetGentleWorkCommand
	assert_true(decoded != null and decoded.gentle, "the command round-trips")
	sim.submit(SetGentleWorkCommand.new(false))  # pending in the save
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	assert_true(loaded.world.work.gentle, "saved with the world")
	loaded.step()
	assert_false(loaded.world.work.gentle, "the pending command survived too")
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v10_basic.json"), content(), errors)
	assert_true(old != null and not old.world.work.gentle, "old saves get varied work: %s" % [errors])


func test_a_bad_gentle_setting_is_refused() -> void:
	var data := SaveCodec.to_dict(_game(9))
	data["world"]["work"] = {"gentle": "yes"}
	var errors: Array[String] = []
	assert_true(SaveCodec.from_dict(data, content(), errors) == null)
	assert_true("\n".join(errors).contains("world.work.gentle"), "\n".join(errors))


func test_the_town_check_counts_lunch_and_keeps_colleagues_apart() -> void:
	var sim := _game(9)
	var town := TownCheck.new()
	var id := sim.world.player_id
	town.observe(sim, {"type": &"action_finished", "data": {"person_id": id, "interaction_id": "work", "minutes": 480}})
	assert_eq(town.meals.get(id, 0), 0, "a shift isn't a meal")
	assert_eq(town.exchanges.get(id, 0), 0, "nor a conversation")
	town.observe(sim, {"type": &"meal_eaten", "data": {"person_id": id, "kind": "lunch"}})
	town.observe(sim, {"type": &"shift_settled", "data": {"person_id": id, "left_early": false, "colleagues": 2}})
	town.observe(sim, {"type": &"shift_settled", "data": {"person_id": id, "left_early": false, "colleagues": 0}})
	assert_eq(town.meals.get(id, 0), 1, "lunch is a meal")
	assert_eq(town.colleague_days.get(id, 0), 1)
	assert_eq(town.exchanges.get(id, 0), 0, "colleagues aren't social exchanges")
	assert_true(town.summary(sim)[0].ends_with("social exchanges 0, colleague days 1"), town.summary(sim)[0])
	var only_colleagues := func(f: String) -> bool: return f.begins_with(sim.world.player().full_name() + " talked with people only 0")
	assert_true(Array(town.failures(sim, 7)).any(only_colleagues), "over a week, a worker who only meets colleagues fails the social rule")
	assert_false(Array(town.failures(sim, 2)).any(only_colleagues), "conversations are judged over a full week (owner, D31)")
