extends TestCase
## T-0035: the residents look after themselves with the same free will as the player.


func test_a_day_in_town_keeps_everyone_fed_rested_and_apart() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var slept: Dictionary[int, bool] = {}
	var ate: Dictionary[int, bool] = {}
	var low := 0
	var samples := 0
	for minute: int in SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] != &"action_finished":
				continue
			var id := int(event["data"]["person_id"])
			match String(event["data"]["interaction_id"]):
				"sleep", "nap":
					slept[id] = true
				var food when TownCheck.EATING.has(food) or food == "work":  # lunch at work (T-0060)
					ate[id] = true
		var used: Dictionary[String, int] = {}
		for person: Person in sim.world.people.values():
			for need_id: String in person.needs:
				samples += 1
				if person.needs[need_id] < 30.0:
					low += 1
			if person.action_queue.is_empty():
				continue
			var action: Action = person.action_queue[0]
			if not sim.world.objects.has(action.target_id):
				continue  # talking to someone: two people may talk to the same person (T-0039)
			if action.state == Action.ROUTING or action.state == Action.PERFORMING:
				var slot := "%d/%d" % [action.target_id, action.slot_index]
				assert_false(used.has(slot), "%d and %d both hold slot %s" % [used.get(slot, 0), person.id, slot])
				used[slot] = person.id
	for person: Person in sim.world.people.values():
		assert_true(slept.has(person.id), "%s slept" % person.full_name())
		assert_true(ate.has(person.id), "%s ate" % person.full_name())
	assert_true(low * 100 < samples * 2, "needs below 30 in %d of %d samples" % [low, samples])


func test_residents_only_use_things_in_their_own_home() -> void:
	var sim := SimFactory.new_game(content(), 3)
	for minute: int in 240:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] != &"autonomy_chose":
				continue
			var person := sim.world.get_person(int(event["data"]["person_id"]))
			var obj := sim.world.get_object(int(event["data"]["target_id"]))
			if obj == null:
				continue  # a person (T-0039); their lot is checked when choosing them
			var lot := Lots.lot_at(sim, obj.origin)
			assert_true(lot == null or Lots.may_enter(sim, person, lot), "%s chose %s" % [person.full_name(), obj.def_id])
