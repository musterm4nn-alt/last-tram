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
	player.job.shifts_worked = 3  # not their first day (that one is forgiven)
	sim.submit(QueueInteractionCommand.new(player.id, "work", _at_shelter(sim, player).id))
	sim.run_minutes(60)
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.DOWN))
	sim.step()
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
	assert_near(player.job.performance, 50.0, 0.001, "judged once the shift is over, not on leaving (T-0077)")
	sim.clock.tick = SimClock.ticks_for(0, 16, 59)
	sim.run_minutes(2)
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


func test_the_first_shift_forgives_lateness() -> void:
	var sim := _game(0, 9, 40)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "work", _at_shelter(sim, player).id))
	sim.run_minutes(8 * 60)
	assert_eq(player.job.shifts_worked, 1)
	assert_true(player.job.performance >= 50.0 + content().economy.performance["shift_done"], "40 minutes late on day one: no penalty")


## Starts the work action with the player already on the shelter's staff slot.
func _start_work(sim: Sim) -> void:
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "work", _at_shelter(sim, player).id))
	sim.step()


## Stops working (cancels the front action) without moving.
func _stop_work(sim: Sim) -> void:
	sim.submit(CancelActionCommand.new(sim.world.player().id, 0))
	sim.step()


## Runs to 17:05 on `day`, after the office shift has ended and been settled.
func _past_shift_end(sim: Sim, day: int) -> void:
	sim.run_minutes((SimClock.ticks_for(day, 17, 5) - sim.clock.tick) / SimClock.STEPS_PER_GAME_MINUTE)


func _settled(events: Array[Dictionary], person_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in events:
		if event["type"] == &"shift_settled" and int(event["data"]["person_id"]) == person_id:
			out.append(event["data"])
	return out


func test_a_split_shift_is_settled_once() -> void:
	var sim := _game(0, 9)
	var player := sim.world.player()
	player.job.shifts_worked = 3
	_start_work(sim)
	sim.run_minutes(3 * 60)
	_stop_work(sim)
	assert_eq(player.job.shifts_worked, 3, "not settled on leaving")
	sim.clock.tick = SimClock.ticks_for(0, 12, 5)
	_start_work(sim)
	_past_shift_end(sim, 0)
	var settled := _settled(sim.events.drain(), player.id)
	assert_eq(settled.size(), 1, "one shift")
	assert_eq(settled[0]["minutes"], 475)
	assert_eq(settled[0]["late_minutes"], 0, "one lateness judgement, from the first arrival")
	assert_false(settled[0]["left_early"])
	assert_eq(player.job.unpaid, 475 * 1400 / 60)
	assert_eq(player.job.shifts_worked, 4)
	assert_eq(player.job.level_shifts, 1)
	assert_true(player.job.performance >= 50.0 + content().economy.performance["shift_done"])


func test_cancelling_before_the_shift_costs_nothing() -> void:
	var sim := _game(0, 8, 10)
	var player := sim.world.player()
	player.job.shifts_worked = 3
	_start_work(sim)
	sim.run_minutes(5)
	_stop_work(sim)
	sim.clock.tick = SimClock.ticks_for(0, 8, 55)
	_start_work(sim)
	_past_shift_end(sim, 0)
	var events := sim.events.drain()
	var settled := _settled(events, player.id)
	assert_eq(settled.size(), 1)
	assert_eq(settled[0]["minutes"], 480)
	assert_false(settled[0]["left_early"])
	assert_false(_types(events, player.id).has(&"shift_missed"))
	assert_true(player.job.performance >= 50.0 + content().economy.performance["shift_done"], "no penalty")
	var gone := _game(0, 8, 10)
	_start_work(gone)
	gone.run_minutes(5)
	_stop_work(gone)
	_past_shift_end(gone, 0)
	var types := _types(gone.events.drain(), gone.world.player().id)
	assert_has(types, &"shift_missed", "minutes before the shift aren't attendance")
	assert_false(types.has(&"shift_settled"))


## Works `segments` stretches of `minutes` each from 09:00 (stopping between them), then
## runs past the end of the shift; returns the player's unpaid wages.
func _pay_for(segments: int, minutes: int) -> int:
	var sim := _game(0, 9)
	for i: int in segments:
		_start_work(sim)
		sim.run_minutes(minutes)
		_stop_work(sim)
	assert_eq(sim.world.player().job.shift_minutes, segments * minutes)
	_past_shift_end(sim, 0)
	return sim.world.player().job.unpaid


func test_pay_does_not_depend_on_interruptions() -> void:
	assert_true(1400 % 60 != 0, "the office wage isn't a whole number of cents a minute")
	var whole := _pay_for(1, 3)
	assert_eq(whole, 3 * 1400 / 60)
	assert_eq(_pay_for(3, 1), whole, "three 1-minute stretches pay like one 3-minute stretch")


func test_an_old_save_made_mid_shift_is_paid_not_missed() -> void:
	var sim := _game(0, 8, 55)
	_start_work(sim)
	sim.run_minutes(60)
	var data := SaveCodec.to_dict(sim)
	data["save_version"] = 9
	for person: Dictionary in data["world"]["people"]:
		if person.get("job") is Dictionary:
			for key: String in ["shift_start", "shift_minutes", "shift_late"]:
				person["job"].erase(key)
			if int(person["id"]) == sim.world.player_id:
				person["job"]["last_shift_start"] = SimClock.ticks_for(0, 9)  # what v9 recorded on arrival
	var errors: Array[String] = []
	var old := SaveCodec.from_dict(data, content(), errors)
	assert_true(old != null, "%s" % [errors])
	if old == null:
		return
	var player := old.world.player()
	assert_eq(player.job.shift_start, SimClock.ticks_for(0, 9))
	assert_true(player.job.shift_minutes >= 55, "the minutes worked before saving count: %d" % player.job.shift_minutes)
	old.events.drain()
	_past_shift_end(old, 0)
	var events := old.events.drain()
	assert_false(_types(events, player.id).has(&"shift_missed"))
	assert_eq(player.job.unpaid, 480 * 1400 / 60, "a full day's pay")


func test_the_job_warning_does_not_repeat() -> void:
	var sim := _game(0, 8)
	var player := sim.world.player()
	var rules := content().economy.performance
	var warnings := func() -> int: return _types(sim.events.drain(), player.id).count(&"job_warning")
	player.job.performance = rules["warn_below"] + 1.0
	Careers._change(sim, player, -2.0)
	assert_eq(warnings.call(), 1)
	Careers._change(sim, player, 4.0)
	Careers._change(sim, player, -4.0)
	assert_eq(warnings.call(), 0, "bobbing around the line: no new warning")
	player.job.performance = rules["warning_clears_at"] - 0.5
	Careers._change(sim, player, 1.0)
	Careers._change(sim, player, rules["warn_below"] - rules["warning_clears_at"] - 2.0)
	assert_eq(warnings.call(), 1, "recovered above warning_clears_at, then fell again")


func test_career_changes_without_a_job_do_nothing() -> void:
	var sim := _game(0, 8)
	var player := sim.world.player()
	player.job.job_id = "no_such_job"
	Careers._change(sim, player, -100.0)
	assert_true(player.job != null and player.job.performance == 50.0)


func test_people_out_of_cash_go_to_the_atm() -> void:
	var sim := _game(1, 12)
	var player := sim.world.player()
	player.job = null
	Money.spend(sim, player, player.wallet.cash, "purchase")
	var options := Autonomy.candidates(sim, player).map(func(o: Dictionary) -> String: return o["interaction_id"])
	assert_true(options.has("withdraw_20") or options.has("withdraw_50"), "no cash: the ATM is an errand")
	Money.withdraw(sim, player, 2000)
	options = Autonomy.candidates(sim, player).map(func(o: Dictionary) -> String: return o["interaction_id"])
	assert_false(options.has("withdraw_20"), "cash in the pocket: no ATM trip")
