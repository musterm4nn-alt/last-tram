extends TestCase
## T-0042: simulation tiers and the "full lives" dial.

const DAY: int = SimClock.MINUTES_PER_DAY


func _residents_far_from(sim: Sim, cells: float) -> Array[Person]:
	var out: Array[Person] = []
	for person: Person in sim.world.people.values():
		if TierSystem.distance_to(person, sim.world.player()) > cells:
			out.append(person)
	return out


func test_near_people_are_active_and_far_ones_background() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.tiers.active_radius = 10.0
	sim.world.tiers.demote_radius = 20.0
	sim.run_minutes(TierSystem.CHECK_MINUTES)
	assert_false(sim.world.player().background, "the player is always active")
	var far := _residents_far_from(sim, 20.0)
	assert_false(far.is_empty())
	for person: Person in far:
		assert_true(person.background, "%s is far away" % person.full_name())
	for person: Person in sim.world.people.values():
		if TierSystem.distance_to(person, sim.world.player()) <= 10.0:
			assert_false(person.background)


func test_hysteresis_and_full_mode() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.tiers.active_radius = 10.0
	sim.world.tiers.demote_radius = 20.0
	sim.clock.tick = SimClock.ticks_for(1, 0, 0)  # a tier-check minute
	var tiers := TierSystem.new()
	var someone: Person = _residents_far_from(sim, 25.0)[0]
	var player := sim.world.player()
	someone.background = true
	player.level = someone.level  # floors count extra (LEVEL_DISTANCE)
	player.pos = someone.pos + Vector2(15, 0)  # between the radii: no change either way
	tiers.on_minute(sim)
	assert_true(someone.background, "15 cells: stays background")
	someone.background = false
	tiers.on_minute(sim)
	assert_false(someone.background, "15 cells: stays active")
	player.pos = someone.pos + Vector2(25, 0)
	tiers.on_minute(sim)
	assert_true(someone.background, "25 cells: demoted")
	player.pos = someone.pos + Vector2(5, 0)
	tiers.on_minute(sim)
	assert_false(someone.background, "5 cells: promoted")
	sim.world.tiers.mode = TierSettings.FULL
	player.pos = someone.pos + Vector2(60, 0)
	tiers.on_minute(sim)
	for person: Person in sim.world.people.values():
		assert_false(person.background, "full lives: everyone active")


func test_talking_to_an_active_person_makes_you_active() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.tiers.active_radius = 5.0
	sim.world.tiers.demote_radius = 8.0
	var far: Person = _residents_far_from(sim, 30.0)[0]
	far.background = true
	sim.world.player().action_queue.append(Action.new("chat", far.id))
	sim.world.player().action_queue[0].id = sim.world.new_id()
	sim.run_minutes(TierSystem.CHECK_MINUTES)
	assert_false(far.background)


func test_promotion_and_demotion_round_trips_keep_people_valid() -> void:
	var sim := SimFactory.new_game(content(), 2)
	var lost := 0
	for minute: int in DAY:
		if minute % 7 == 0:
			var flip := (minute / 7) % 2 == 0
			sim.world.tiers.active_radius = 0.0 if flip else 1000.0
			sim.world.tiers.demote_radius = 0.0 if flip else 1000.0
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"action_failed" and String(event["data"]["reason"]) in ["target_unavailable", "unknown_interaction"]:
				lost += 1
		var used: Dictionary[String, int] = {}
		for person: Person in sim.world.people.values():
			assert_false(MovementSystem.is_box_blocked(sim.world.grid, person.level, person.pos), "%s in a wall at %s" % [person.full_name(), person.pos])
			if person.action_queue.is_empty() or not sim.world.objects.has(person.action_queue[0].target_id):
				continue
			var action: Action = person.action_queue[0]
			if action.state != Action.QUEUED:
				var slot := "%d/%d" % [action.target_id, action.slot_index]
				assert_false(used.has(slot), "slot %s held twice" % slot)
				used[slot] = person.id
	assert_eq(lost, 0, "no action lost its target")


func test_tiered_and_full_towns_live_the_same_lives() -> void:
	var runs: Array[Dictionary] = []
	for mode: String in [TierSettings.FULL, TierSettings.TIERED]:
		var sim := SimFactory.new_game(content(), 3)
		sim.world.tiers.mode = mode
		sim.world.tiers.active_radius = 10.0
		sim.world.tiers.demote_radius = 15.0
		var stats := {"needs": 0.0, "samples": 0, "exchanges": 0, "sleeps": 0, "meals": 0, "background": 0}
		for minute: int in 2 * DAY:
			sim.run_minutes(1)
			for event: Dictionary in sim.events.drain():
				match event["type"]:
					&"social_exchange":
						stats["exchanges"] += 1
					&"action_finished":
						match String(event["data"]["interaction_id"]):
							"sleep":
								stats["sleeps"] += 1
							"cook_meal", "grab_snack":
								stats["meals"] += 1
			for person: Person in sim.world.people.values():
				if person.background:
					stats["background"] += 1
				for need_id: String in person.needs:
					stats["needs"] += person.needs[need_id]
					stats["samples"] += 1
		runs.append(stats)
	assert_eq(runs[0]["background"], 0, "full: nobody in the background")
	assert_true(runs[1]["background"] > 0, "tiered: some people were background")
	var avg_full: float = runs[0]["needs"] / runs[0]["samples"]
	var avg_tiered: float = runs[1]["needs"] / runs[1]["samples"]
	assert_true(absf(avg_full - avg_tiered) < 4.0, "average needs %.1f vs %.1f" % [avg_full, avg_tiered])
	for key: String in ["exchanges", "sleeps", "meals"]:
		var a := float(runs[0][key])
		var b := float(runs[1][key])
		assert_true(absf(a - b) <= 0.25 * maxf(a, b), "%s: %d vs %d" % [key, a, b])


func test_tiers_survive_saving() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.submit(SetTierModeCommand.new(TierSettings.FULL))
	sim.world.tiers.active_radius = 12.0
	sim.step()
	var someone: Person = sim.world.people.values()[5]
	someone.background = true
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_eq(loaded.world.tiers.mode, TierSettings.FULL)
	assert_eq(loaded.world.tiers.active_radius, 12.0)
	assert_true(loaded.world.get_person(someone.id).background)
