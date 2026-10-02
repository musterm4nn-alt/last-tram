extends TestCase
## T-0059: the work action, staff slots, and the rabbit hole.

const MONDAY: int = 0
const SATURDAY: int = 5


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game at `day` `hour`:`minute`; everyone counts as just having had input, and the
## player (an office clerk, free will off) stands on the tram shelter's first slot.
func _game(day: int, hour: int, minute: int = 0) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	_stand_on(sim, player, _object(sim, "tram_stop"), 0)
	sim.events.drain()
	return sim


func _stand_on(sim: Sim, person: Person, obj: WorldObject, slot: int) -> void:
	var cell := obj.slot_cell(content(), slot)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z
	person.path.clear()


func _events(sim: Sim, type: StringName, person_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type and int(event["data"].get("person_id", -1)) == person_id:
			out.append(event["data"])
	return out


func _work(sim: Sim, person: Person, def_id: String) -> void:
	sim.submit(QueueInteractionCommand.new(person.id, "work", _object(sim, def_id).id))


func test_work_uses_staff_slots_and_buying_uses_customer_slots() -> void:
	var sim := _game(MONDAY, 12)
	var counter := _object(sim, "imbiss_counter")
	var work := content().interaction("work")
	var doener := content().interaction("eat_doener")
	var staff := 0
	for slot: int in counter.slot_count(content()):
		assert_ne(Interactions.slot_fits(sim, counter.id, slot, work), Interactions.slot_fits(sim, counter.id, slot, doener), "each slot is for one or the other")
		staff += 1 if Interactions.slot_fits(sim, counter.id, slot, work) else 0
	assert_eq(staff, 1, "one place behind the counter")
	var cook := Jobs.holder(sim.world, "imbiss_cook", 0)
	cook.free_will = false
	_stand_on(sim, cook, counter, 0)
	_work(sim, cook, "imbiss_counter")
	sim.run_minutes(3)
	assert_true(Jobs.working(sim, cook), "walked round behind the counter and started")
	assert_true(Interactions.slot_fits(sim, counter.id, cook.action_queue[0].slot_index, work))
	var shelter := _object(sim, "tram_stop")
	var resident := Jobs.holder(sim.world, "police_officer", 0)
	_stand_on(sim, resident, shelter, 0)
	assert_eq(Autonomy._cells_to_free_slot(sim, resident, shelter), -1, "free will never uses staff slots")


func test_work_is_offered_only_on_your_shift_at_your_workplace() -> void:
	var sim := _game(MONDAY, 8)
	var player := sim.world.player()
	var shelter := _object(sim, "tram_stop")
	var work := content().interaction("work")
	assert_eq(Requirements.check(sim, player, work, shelter.id), "")
	assert_eq(InteractionMenu.entries(sim, shelter.id), ["Tram shelter", "Work"])
	assert_eq(Requirements.check(sim, player, work, _object(sim, "police_desk").id), "not_your_job")
	assert_eq(InteractionMenu.entries(sim, _object(sim, "police_desk").id), ["Desk", InteractionMenu.NOTHING], "someone else's job isn't shown")
	sim.clock.tick = SimClock.ticks_for(MONDAY, 7, 30)
	assert_eq(Requirements.check(sim, player, work, shelter.id), "not_your_shift")
	assert_eq(InteractionMenu.entries(sim, shelter.id), ["Tram shelter", "Work (not your shift)"])
	sim.clock.tick = SimClock.ticks_for(SATURDAY, 10)
	assert_eq(Requirements.check(sim, player, work, shelter.id), "not_your_shift")
	sim.clock.tick = SimClock.ticks_for(MONDAY, 17)
	assert_eq(Requirements.check(sim, player, work, shelter.id), "not_your_shift", "the shift is over")


func test_a_day_at_work_in_the_rabbit_hole() -> void:
	var sim := _game(MONDAY, 8, 55)
	var player := sim.world.player()
	var energy := float(player.needs["energy"])
	_work(sim, player, "tram_stop")
	sim.step()
	var started := _events(sim, &"shift_started", player.id)
	assert_eq(started.size(), 1)
	assert_eq(started[0]["late_minutes"], 0)
	assert_true(Jobs.hidden(sim, player), "took the tram")
	assert_false(Conversations.available(sim, player), "nobody can talk to you at work")
	sim.run_minutes(60)
	var decay := content().need("energy").decay_per_hour
	assert_near(float(player.needs["energy"]), energy - decay + content().job("office_clerk").need_rates.get("energy", 0.0), 0.2)
	sim.run_minutes(7 * 60 + 3)
	assert_true(Jobs.working(sim, player), "still at work at 16:58")
	sim.run_minutes(3)
	assert_false(Jobs.working(sim, player), "home time at 17:00")
	assert_false(Jobs.hidden(sim, player))
	var ended := _events(sim, &"shift_ended", player.id)
	assert_eq(ended.size(), 1)
	assert_eq(ended[0]["minutes"], 480)
	assert_false(ended[0]["left_early"])
	assert_eq(player.cell(), _object(sim, "tram_stop").slot_cell(content(), 0), "back at the stop")


func test_leaving_early_and_being_late() -> void:
	var sim := _game(MONDAY, 9, 20)
	var player := sim.world.player()
	_work(sim, player, "tram_stop")
	sim.step()
	assert_eq(_events(sim, &"shift_started", player.id)[0]["late_minutes"], 20)
	sim.run_minutes(160)
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.DOWN))
	sim.step()
	var ended := _events(sim, &"shift_ended", player.id)
	assert_eq(ended.size(), 1)
	assert_true(ended[0]["left_early"])
	assert_eq(ended[0]["minutes"], 160)
	assert_eq(ended[0]["late_minutes"], 20)


func test_a_night_shift_ends_after_midnight() -> void:
	var sim := _game(MONDAY, 17)
	var bartender := Jobs.holder(sim.world, "bartender", 0)
	bartender.free_will = false
	var bar := _object(sim, "bar_counter")
	var staff_slot := -1
	for slot: int in bar.slot_count(content()):
		if Interactions.slot_fits(sim, bar.id, slot, content().interaction("work")):
			staff_slot = slot
			break
	_stand_on(sim, bartender, bar, staff_slot)
	_work(sim, bartender, "bar_counter")
	sim.run_minutes(8 * 60 + 58)
	assert_true(Jobs.working(sim, bartender), "still working at 01:58")
	sim.run_minutes(3)
	assert_false(Jobs.working(sim, bartender), "the Kneipe closes at 02:00")
	assert_eq(_events(sim, &"shift_ended", bartender.id)[0]["minutes"], 540)


func test_saving_mid_shift_continues_identically() -> void:
	var sim := _game(MONDAY, 8, 50)
	_work(sim, sim.world.player(), "tram_stop")
	sim.run_minutes(60)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	sim.run_minutes(9 * 60)
	loaded.run_minutes(9 * 60)
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	assert_false(Jobs.working(loaded, loaded.world.player()))
