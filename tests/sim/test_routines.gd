extends TestCase
## T-0036: daily routines: a sleep window, sleeping through it, and going home.

const DIR: String = "user://test_t0036_routines"
const ROOM: PackedStringArray = ["########", "#@.....#", "########"]


func after_each() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for file: String in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file))
		DirAccess.remove_absolute(DIR)


func _load_routines(data: Dictionary) -> ContentReader:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR.path_join("routines.json"), FileAccess.WRITE)
	file.store_string(Ser.to_json(data))
	file.close()
	var reader := ContentReader.new()
	RoutineLoader.load(ContentDB.new(), reader, DIR.path_join("routines.json"))
	return reader


func _at(sim: Sim, hour: int) -> void:
	sim.clock.tick = SimClock.ticks_for(sim.clock.day() + 1, hour)
	for person: Person in sim.world.people.values():
		person.last_input_tick = mini(person.last_input_tick, sim.clock.tick)


func _asleep(sim: Sim, person: Person) -> bool:
	if person.action_queue.is_empty() or person.action_queue[0].state != Action.PERFORMING:
		return false
	return sim.content.interaction(person.action_queue[0].interaction_id).routine == "sleep"


func test_routines_load_and_bad_ones_are_reported() -> void:
	assert_eq(content().default_routine, "regular")
	assert_eq(content().routine("night_owl").sleep_hours, Vector2i(2, 10))
	assert_eq(content().interaction("sleep").routine, "sleep")
	var good := {"default": "a", "routines": [{"id": "a", "name": "A", "sleep_hours": [23, 7], "out_hours": [19, 23], "weight": 1}]}
	assert_true(_load_routines(good).errors.is_empty())
	var bad_hours := good.duplicate(true)
	bad_hours["routines"][0]["sleep_hours"] = [25, 7]
	assert_false(_load_routines(bad_hours).errors.is_empty(), "hour 25")
	var bad_default := good.duplicate(true)
	bad_default["default"] = "b"
	assert_false(_load_routines(bad_default).errors.is_empty(), "unknown default")


func test_the_player_is_regular_and_residents_get_every_routine() -> void:
	var seen: Dictionary[String, bool] = {}
	for seed_value: int in range(1, 11):
		var sim := SimFactory.new_game(content(), seed_value)
		assert_eq(sim.world.player().routine_id, "regular")
		for person: Person in sim.world.people.values():
			assert_true(content().routine(person.routine_id) != null, "a known routine")
			seen[person.routine_id] = true
	for id: String in content().routines:
		assert_true(seen.has(id), "someone is a %s" % id)


func test_sleep_scores_double_in_the_window_and_less_outside() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var sleep := content().interaction("sleep")
	_at(sim, 23)
	assert_eq(Routines.score_factor(sim, player, sleep), Routines.SLEEP_IN_WINDOW)
	_at(sim, 14)
	assert_eq(Routines.score_factor(sim, player, sleep), Routines.SLEEP_OUTSIDE)
	assert_eq(Routines.score_factor(sim, player, content().interaction("watch_tv")), 1.0)
	assert_true(Routines.in_hours(Vector2i(23, 7), 2))
	assert_false(Routines.in_hours(Vector2i(23, 7), 7))
	assert_true(Routines.in_hours(Vector2i(2, 10), 9))


func test_sleepers_stay_in_bed_until_the_window_ends() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.free_will = false
	_at(sim, 2)
	player.needs["energy"] = 99.0
	sim.submit(QueueInteractionCommand.new(player.id, "sleep", _object(sim, "bed_double")))
	sim.run_minutes(120)
	assert_true(_asleep(sim, player), "energy is full, but it is 04:00: still asleep")
	assert_true(player.needs["energy"] > 99.9, "rested (refilled each minute, then the usual drain)")
	sim.run_minutes(4 * 60)
	assert_false(_asleep(sim, player), "woke up after 07:00")


func test_outside_the_window_sleep_ends_at_full_energy() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.free_will = false
	_at(sim, 13)
	player.needs["energy"] = 90.0
	sim.submit(QueueInteractionCommand.new(player.id, "sleep", _object(sim, "bed_double")))
	sim.run_minutes(75)
	assert_false(_asleep(sim, player), "a 60-minute minimum, then full energy ends it")


func test_idle_away_from_home_with_nothing_to_do_walks_home() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_at(sim, 15)
	player.job = null  # 15:00 on a weekday would be work time (T-0060)
	player.pos = Vector2(30.5, 30.5)  # the Altmarkt
	for need_id: String in player.needs:
		player.needs[need_id] = 95.0
	player.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	var headed := false
	for minute: int in 30:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"heading_home" and int(event["data"]["person_id"]) == player.id:
				headed = true
	assert_true(headed)
	assert_true(Routines.at_home(sim, player), "arrived at Haus 12")


func test_out_in_the_sleep_window_heads_home_first() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_at(sim, 1)
	player.pos = Vector2(30.5, 30.5)
	player.needs["hunger"] = 20.0  # hungry, but it is bedtime and there is no food here
	player.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	sim.run_minutes(1)
	assert_false(player.path.is_empty() and player.action_queue.is_empty(), "on the way home")
	# Since T-0060 a hungry person heads home to cook there (their own food), rather than just home.
	if not player.action_queue.is_empty():
		var target := sim.world.get_object(player.action_queue[0].target_id)
		assert_true(target != null and Lots.lot_at(sim, target.origin).id == player.home_lot_id, "what they head for is at home")


func test_the_town_sleeps_at_night_and_is_awake_in_the_afternoon() -> void:
	var sim := SimFactory.new_game(content(), 2)
	# 05:00: night owls go out until 2 and walk home from the Kneipe (T-0052).
	sim.run_minutes(SimClock.MINUTES_PER_DAY + 21 * 60)  # Tuesday 05:00
	var asleep := 0
	for person: Person in sim.world.people.values():
		if _asleep(sim, person) and Routines.at_home(sim, person):
			asleep += 1
	assert_true(asleep * 4 >= sim.world.people.size() * 3, "%d of %d asleep at home at 05:00" % [asleep, sim.world.people.size()])
	sim.run_minutes(10 * 60)  # 15:00
	asleep = 0
	for person: Person in sim.world.people.values():
		if _asleep(sim, person):
			asleep += 1
	assert_true(asleep * 10 <= sim.world.people.size(), "%d of %d asleep at 15:00" % [asleep, sim.world.people.size()])


func test_routine_survives_saving() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var someone: Person = sim.world.people.values()[3]
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_eq(loaded.world.get_person(someone.id).routine_id, someone.routine_id)


func _object(sim: Sim, def_id: String) -> int:
	var ids: Array = sim.world.objects.keys()
	ids.sort()
	for id: int in ids:
		if sim.world.objects[id].def_id == def_id:
			return id
	return 0


func test_hunger_wakes_a_sleeper() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.free_will = false
	_at(sim, 2)
	player.needs["energy"] = 30.0
	player.needs["hunger"] = 16.0
	sim.submit(QueueInteractionCommand.new(player.id, "sleep", _object(sim, "bed_double")))
	sim.run_minutes(50)
	assert_true(_asleep(sim, player), "hunger is critical, but the first hour of sleep is kept")
	sim.run_minutes(15)
	assert_false(_asleep(sim, player), "starving at 03:00: up to eat, not asleep until 07:00")
	assert_true(player.needs["hunger"] < 15.0)
