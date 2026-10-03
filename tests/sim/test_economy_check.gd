extends TestCase
## T-0076: the M3 economy check in the suite: a day of the full town passes it, and it notices
## a broken ledger, mass bankruptcy, a collapse in employment, mass eviction and unstaffed
## shops. The 30-day version is `tools/simrun.sh --days=30 --check-m3`.


## Runs `days` days of the town through both checks.
func _run(sim: Sim, economy: EconomyCheck, town: TownCheck, days: int) -> void:
	for minute: int in days * SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			town.observe(sim, event)
			economy.observe(sim, event)
		town.sample(sim)
		if sim.clock.minute_of_day() == 0:
			economy.end_of_day(sim)


func _started(sim: Sim) -> EconomyCheck:
	var economy := EconomyCheck.new()
	economy.start(sim)
	return economy


func _mentions(problems: PackedStringArray, text: String) -> bool:
	return Array(problems).any(func(p: String) -> bool: return p.contains(text))


func test_a_day_in_town_passes_the_economy_check() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	var town := TownCheck.new()
	_run(sim, economy, town, 1)
	assert_eq(economy.days, 1)
	assert_true(economy.start_employment > 50.0, "most working-age residents start with a job: %.0f%%" % economy.start_employment)
	assert_eq(economy.failures(sim, town), PackedStringArray())
	print("        ", economy.summary())


func test_the_check_notices_money_from_nowhere() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	sim.world.player().wallet.bank += 100
	economy.end_of_day(sim)
	assert_true(_mentions(economy.failures(sim, TownCheck.new()), "the ledger says"), "%s" % [economy.problems])


func test_the_check_notices_mass_bankruptcy() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	var people: Array = sim.world.people.values()
	for i: int in people.size() / 5:
		var person: Person = people[i]
		Money.spend(sim, person, person.wallet.total(), "purchase")
	economy.end_of_day(sim)
	var problems := economy.failures(sim, TownCheck.new())
	assert_eq(problems.size(), 1, "%s" % [problems])
	assert_true(_mentions(problems, "are broke"), "%s" % [problems])
	assert_eq(economy.most_broke, EconomyCheck.broke_people(sim).size())


func test_the_check_notices_employment_collapsing() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	for person: Person in sim.world.people.values():
		if person.job != null and person.id != sim.world.player_id:
			Careers.fire(sim, person, "test")
	economy.end_of_day(sim)
	assert_near(EconomyCheck.employment_rate(sim), 0.0)
	assert_true(_mentions(economy.failures(sim, TownCheck.new()), "employment is 0%"), "%s" % [economy.problems])


func test_the_check_notices_mass_eviction() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids.slice(1, 3):
		var household: Household = sim.world.households[id]
		sim.world.lots[household.home_lot_id].weeks_behind = content().economy.evict_after_weeks
	sim.events.drain()
	Moving.evict_overdue(sim)
	for event: Dictionary in sim.events.drain():
		economy.observe(sim, event)
	assert_eq(economy.evictions, 2)
	assert_has(economy.failures(sim, TownCheck.new()), "2 households were evicted")


func test_the_check_notices_an_unstaffed_shop() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var economy := _started(sim)
	var town := TownCheck.new()
	var place_id: String = Staffing.places(content())[0]
	town.open_minutes[place_id] = 100
	town.staffed_minutes[place_id] = 79
	assert_true(_mentions(economy.failures(sim, town), "staffed only 79%"))
	town.staffed_minutes[place_id] = 80
	assert_eq(economy.failures(sim, town), PackedStringArray(), "80% is enough for M3")
