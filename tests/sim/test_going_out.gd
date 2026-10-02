extends TestCase
## T-0052: in their evening window people go out to the Kneipe, the café and the benches.

const PUBLIC_DEFS: PackedStringArray = ["bar_counter", "pub_table", "cafe_table", "bench"]


func _at(sim: Sim, hour: int) -> void:
	sim.clock.tick = SimClock.ticks_for(sim.clock.day() + 1, hour)


func _idle(sim: Sim, person: Person) -> void:
	person.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	person.autonomy_retry_tick = 0


func _offers(sim: Sim, person: Person, def_id: String) -> bool:
	for option: Dictionary in Autonomy.candidates(sim, person):
		if sim.world.get_object(int(option["object_id"])).def_id == def_id:
			return true
	return false


func test_public_furniture_loads_and_is_placed_usably() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	for id: String in ["have_a_drink", "have_a_coffee", "sit_outside"]:
		assert_eq(content().interaction(id).routine, "out")
	var sim := SimFactory.new_game(content(), 1)
	var counts: Dictionary[String, int] = {}
	for obj: WorldObject in sim.world.objects.values():
		if PUBLIC_DEFS.has(obj.def_id):
			counts[obj.def_id] = counts.get(obj.def_id, 0) + 1
	assert_eq(counts, {"bar_counter": 1, "pub_table": 2, "cafe_table": 4, "bench": 4} as Dictionary[String, int])


func test_the_out_bonus_needs_the_window_and_grows_with_sociability() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	var person := sim.world.player()
	var drink := content().interaction("have_a_drink")
	_at(sim, 20)
	person.personality.set_axis("sociability", -100)
	var loner := Routines.score_bonus(sim, person, drink)
	person.personality.set_axis("sociability", 100)
	var outgoing := Routines.score_bonus(sim, person, drink)
	assert_true(loner > 0.0 and outgoing > loner, "%s < %s" % [loner, outgoing])
	_at(sim, 14)
	assert_eq(Routines.score_bonus(sim, person, drink), 0.0)
	assert_eq(Routines.score_factor(sim, person, drink), Routines.OUT_OUTSIDE)


func test_in_the_evening_the_kneipe_is_an_option_from_home() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_at(sim, 20)
	ShopStaff.serve_now(sim)
	assert_true(_offers(sim, player, "bar_counter"), "20:00: the Kneipe is open and it is going-out time")
	_at(sim, 14)
	assert_false(_offers(sim, player, "bar_counter"), "14:00: not going-out time, and the Kneipe is far")


func test_a_closed_place_offers_nothing() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_at(sim, 20)
	assert_false(_offers(sim, player, "cafe_table"), "Café Wolke closes at 19:00")
	player.routine_id = "early_bird"  # out from 17:00
	_at(sim, 17)
	assert_false(_offers(sim, player, "cafe_table"), "open, but the barista isn't in (T-0065)")
	ShopStaff.serve_now(sim)
	assert_true(_offers(sim, player, "cafe_table"))


func test_over_two_days_people_go_out_and_still_sleep_at_home() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var done: Dictionary[String, int] = {}
	for minute: int in 2 * SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"action_finished":
				var id := String(event["data"]["interaction_id"])
				done[id] = done.get(id, 0) + 1
	# Coffee needs an early bird (the café closes at 19:00); test_a_closed_place_offers_nothing
	# covers it, so the town-wide count only expects drinks and benches.
	for id: String in ["have_a_drink", "sit_outside"]:
		assert_true(done.get(id, 0) > 0, "someone did %s: %s" % [id, done])
