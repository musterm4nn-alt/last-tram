extends TestCase
## T-0076: M3 acceptance for the player. A student with no job applies, is hired, works their
## shifts, is paid on Friday, pays rent on Monday, then misses shifts and is fired, with a save
## and load in the middle. The clock jumps between the moments that matter; the town runs
## through each of them.


## A new town (seed 1) with a jobless student player who looks after nothing by themselves.
func _game() -> Sim:
	var spec := CharacterSpec.default_player(content())
	spec.background = "student"
	var sim := SimFactory.new_game(content(), 1, spec)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


## Sets the clock to `day` at `hour`:`minute`, if that is later; nobody counts as idle.
func _jump(sim: Sim, day: int, hour: int, minute: int = 0) -> void:
	sim.clock.tick = maxi(sim.clock.tick, SimClock.ticks_for(day, hour, minute))
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick


## Runs `minutes` game minutes and returns the player's events in them.
func _run(sim: Sim, minutes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for minute: int in minutes:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if int(event["data"].get("person_id", -1)) == sim.world.player_id:
				out.append(event)
	return out


func _types(events: Array[Dictionary]) -> Array:
	return events.map(func(e: Dictionary) -> StringName: return e["type"])


## The player applies for an office clerk position at noon each day until hired; the day.
func _get_hired(sim: Sim) -> int:
	var player := sim.world.player()
	for day: int in 10:
		_jump(sim, day, 12)
		player.needs["hygiene"] = 100.0
		for vacancy: Dictionary in Jobs.vacancies(sim):
			if vacancy["job_id"] == "office_clerk":
				sim.submit(ApplyForJobCommand.new(player.id, vacancy["job_id"], vacancy["position"]))
				break
		_run(sim, 1)
		if player.job != null:
			return day
	return -1


## Works the player's office shift on `day`: at the tram stop's staff slot at 08:55, until
## the shift is settled at 17:05.
func _work_shift(sim: Sim, day: int) -> Array[Dictionary]:
	_jump(sim, day, 8, 55)
	var player := sim.world.player()
	var stop := Jobs.workplace(sim, player)
	var cell := stop.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.submit(QueueInteractionCommand.new(player.id, "work", stop.id))
	return _run(sim, 8 * 60 + 10)


## Lets the player's shift on `day` pass without them (to 17:05).
func _miss_shift(sim: Sim, day: int) -> Array[Dictionary]:
	_jump(sim, day, 16, 55)
	return _run(sim, 10)


func _reload(sim: Sim) -> Sim:
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	return loaded


func test_hired_paid_pays_rent_and_fired() -> void:
	var sim := _game()
	assert_eq(sim.world.player().job, null, "a student starts without a job")
	var applied := _get_hired(sim)
	assert_true(applied >= 0 and applied < 4, "hired in the first week (applied on day %d)" % applied)
	if applied < 0:
		return
	var job := sim.world.player().job
	assert_eq(job.job_id, "office_clerk")
	assert_eq(job.hired_day, applied + 1, "starts the next day")

	# Work every shift from the first day to Friday (day 4), saving and loading after the first.
	var worked := 0
	for day: int in range(job.hired_day, 5):
		if Jobs.shift_on(sim, sim.world.player(), day) == Vector2i(-1, -1):
			continue
		var events := _work_shift(sim, day)
		assert_has(_types(events), &"shift_started", "day %d" % day)
		worked += 1
		if worked == 1:
			sim = _reload(sim)
			if sim == null:
				return
	var player := sim.world.player()
	assert_true(worked >= 2, "shifts on both sides of the save: %d" % worked)
	assert_eq(player.job.shifts_worked, worked)
	var wages := player.job.unpaid
	assert_eq(wages, worked * 8 * 1400, "eight hours at €14 a shift")

	# Payday: Friday at 18:00.
	var bank := player.wallet.bank
	_jump(sim, 4, 17, 55)
	_run(sim, 10)
	assert_eq(player.wallet.bank, bank + wages, "the week's wages")
	assert_eq(player.job.unpaid, 0)
	assert_has(player.wallet.statement.map(func(e: Dictionary) -> String: return e["reason"]), "wage")

	# Rent day: Monday (day 7) at 08:00, rent and bills from the bank.
	bank = player.wallet.bank
	var lot: Lot = sim.world.lots[player.home_lot_id]
	var rent := Housing.rent_share(sim, player)
	assert_eq(Groceries.home_household(sim, player).member_ids.size(), 1, "the player lives alone")
	_jump(sim, 6, 23, 55)
	_run(sim, 8 * 60 + 10)
	assert_true(rent > 0)
	assert_eq(player.wallet.bank, bank - rent - content().economy.bills_week, "rent and bills paid")
	assert_eq(lot.arrears, 0, "nothing owed")
	assert_eq(player.home_lot_id, lot.id, "still at home")

	# Missing shifts from Monday on: a warning, then the sack.
	var types: Array = []
	for day: int in range(7, 14):
		if player.job == null:
			break
		if Jobs.shift_on(sim, player, day) != Vector2i(-1, -1):
			types.append_array(_types(_miss_shift(sim, day)))
	assert_has(types, &"shift_missed")
	assert_has(types, &"job_warning")
	assert_has(types, &"fired")
	assert_true(types.find(&"job_warning") < types.find(&"fired"), "warned first")
	assert_eq(player.job, null, "fired")
	assert_eq(Money.held(sim.world), sim.world.ledger.balance(), "money conserved throughout")
