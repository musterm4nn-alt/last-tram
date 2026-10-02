extends TestCase
## T-0061: pay, payday, performance, promotion, warnings and getting fired.


func _game(day: int, hour: int, minute: int = 0) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	sim.events.drain()
	return sim


func _at_shelter(sim: Sim, person: Person) -> WorldObject:
	var shelter := Jobs.workplace(sim, person)
	var cell := shelter.slot_cell(content(), 0)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z
	return shelter


## Works the player's whole shift on `day` (arriving at 08:55) and returns the events of it.
func _work_day(sim: Sim, day: int) -> Array[Dictionary]:
	var player := sim.world.player()
	sim.clock.tick = maxi(sim.clock.tick, SimClock.ticks_for(day, 8, 55))
	sim.submit(QueueInteractionCommand.new(player.id, "work", _at_shelter(sim, player).id))
	sim.run_minutes(8 * 60 + 10)
	return sim.events.drain()


func _types(events: Array[Dictionary], person_id: int) -> Array:
	return events.filter(func(e: Dictionary) -> bool: return int(e["data"].get("person_id", -1)) == person_id).map(func(e: Dictionary) -> StringName: return e["type"])


func test_a_shift_earns_its_wage_and_payday_pays_it() -> void:
	var sim := _game(0, 8, 55)
	var player := sim.world.player()
	_work_day(sim, 0)
	assert_eq(player.job.unpaid, 480 * 1400 / 60, "eight hours at €14")
	assert_eq(player.job.shifts_worked, 1)
	assert_true(player.job.performance > 50.0)
	var bank := player.wallet.bank
	sim.clock.tick = SimClock.ticks_for(4, 17, 59)
	sim.run_minutes(2)
	assert_eq(player.wallet.bank, bank + 480 * 1400 / 60, "paid on Friday at 18:00")
	assert_eq(player.job.unpaid, 0)
	assert_eq(player.wallet.statement.back()["reason"], "wage")
	assert_eq(Money.held(sim.world), sim.world.ledger.balance())


func test_lateness_and_leaving_early_cost_performance() -> void:
	var sim := _game(0, 9, 30)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "work", _at_shelter(sim, player).id))
	sim.run_minutes(60)
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.DOWN))
	sim.step()
	var rules := content().economy.performance
	assert_near(player.job.performance, 50.0 - rules["left_early"] - 6.0 * rules["per_5_minutes_late"], 0.001)
	assert_eq(player.job.unpaid, 60 * 1400 / 60, "paid for the minutes worked")


func test_missed_shifts_bring_a_warning_and_then_the_sack() -> void:
	var sim := _game(0, 8)
	var player := sim.world.player()
	var events: Array[Dictionary] = []
	for day: int in 3:
		sim.clock.tick = SimClock.ticks_for(day, 16, 59)
		sim.run_minutes(2)
		events.append_array(sim.events.drain())
	var types := _types(events, player.id)
	assert_eq(types.count(&"shift_missed"), 3)
	assert_has(types, &"job_warning")
	assert_has(types, &"fired")
	assert_true(player.job == null, "three missed shifts: fired")
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "fired"))
	assert_true(Jobs.holder(sim.world, "office_clerk", 0) == null, "the position is open again")


func test_good_work_gets_a_promotion() -> void:
	var sim := _game(0, 8)
	var player := sim.world.player()
	player.job.performance = 79.0
	player.job.level_shifts = int(content().economy.performance["promote_after_shifts"]) - 1
	var events := _work_day(sim, 0)
	assert_eq(player.job.level, 1)
	assert_has(_types(events, player.id), &"promoted")
	assert_near(player.job.performance, content().economy.performance["after_promotion"], 0.001)
	assert_eq(PersonInspector.job_text(sim, player), "Senior clerk (Mon–Fri 9–17), doing okay")


func test_career_notices() -> void:
	assert_eq(Hud.career_notice({"type": &"wages_paid", "data": {"amount": 56000}}, content()), "Payday: €560.00 wages in the bank")
	assert_eq(Hud.career_notice({"type": &"promoted", "data": {"title": "Senior clerk"}}, content()), "Promoted: you're now Senior clerk!")
	assert_eq(Hud.career_notice({"type": &"fired", "data": {"job_id": "office_clerk"}}, content()), "You were fired from your job as Office clerk")
	assert_eq(Hud.career_notice({"type": &"job_warning", "data": {"job_id": "office_clerk"}}, content()), "Your boss warned you about your work (Office clerk)")


func test_pay_records_survive_saving() -> void:
	var sim := _game(0, 8, 55)
	_work_day(sim, 0)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		assert_eq(loaded.world.player().job.to_dict(), sim.world.player().job.to_dict())
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v6_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	if old != null:
		assert_eq(old.world.player().job.unpaid, 0)
		assert_eq(old.world.player().job.last_shift_start, -1)
