extends TestCase
## T-0062: rent and bills on Monday, arrears, benefit and pensions.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.events.drain()
	return sim


## Runs the sim from Sunday 23:59 to Monday 08:01 of week `week` (1 = the first Monday after
## the start).
func _to_monday(sim: Sim, week: int) -> Array[Dictionary]:
	sim.clock.tick = SimClock.ticks_for(7 * week - 1, 23, 59)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var out: Array[Dictionary] = []
	for minute: int in 8 * 60 + 2:
		sim.run_minutes(1)
		out.append_array(sim.events.drain())
	return out


func _player_home(sim: Sim) -> Household:
	return Groceries.home_household(sim, sim.world.player())


func test_rent_and_bills_come_out_on_monday() -> void:
	var sim := _game()
	var player := sim.world.player()
	var bank := player.wallet.bank
	var place := content().place("home_player")
	_to_monday(sim, 1)
	var rent := place.rent
	assert_eq(_player_home(sim).member_ids.size(), 1)
	assert_true(player.wallet.bank <= bank - rent - content().economy.bills_week, "rent and bills paid")
	var reasons := player.wallet.statement.map(func(e: Dictionary) -> String: return e["reason"])
	assert_has(reasons, "rent")
	assert_has(reasons, "bill")
	assert_eq(sim.world.lots[player.home_lot_id].arrears, 0)


func test_unpaid_rent_becomes_arrears_and_is_paid_off_later() -> void:
	var sim := _game()
	var player := sim.world.player()
	player.job = null
	Money.charge(sim, player, player.wallet.bank, "bill")
	var events := _to_monday(sim, 1)
	var lot: Lot = sim.world.lots[player.home_lot_id]
	assert_eq(lot.arrears, content().place("home_player").rent + content().economy.bills_week)
	assert_eq(lot.weeks_behind, 1)
	var unpaid := events.filter(func(e: Dictionary) -> bool: return e["type"] == &"rent_unpaid" and int(e["data"]["household_id"]) == player.household_id)
	assert_eq(unpaid.size(), 1)
	assert_eq(int(unpaid[0]["data"]["owed"]), 20500)
	assert_eq(int(unpaid[0]["data"]["weeks_behind"]), 1)
	Money.earn(sim, player, 100000, "found")
	_to_monday(sim, 2)
	assert_eq(lot.arrears, 0, "a full week also pays off what was owed")
	assert_eq(lot.weeks_behind, 0)


func test_benefit_covers_an_unemployed_residents_rent() -> void:
	var sim := _game()
	var someone: Person = null
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id and person.age_years < 67 and Groceries.home_household(sim, person) != null:
			someone = person
			someone.job = null  # every working-age resident of this town has a job since T-0065
			break
	assert_true(someone != null and someone.benefit_registered)
	var share := Housing.rent_share(sim, someone)
	var economy := content().economy
	var bank := someone.wallet.bank
	_to_monday(sim, 1)
	var benefit := someone.wallet.statement.filter(func(e: Dictionary) -> bool: return e["reason"] == "benefit")
	assert_eq(benefit.size(), 1)
	assert_eq(benefit[0]["amount"], economy.benefit_week + mini(share, economy.housing_cap))
	assert_true(someone.wallet.bank >= bank + economy.benefit_week - economy.bills_week, "benefit covers the rent share")


func test_pensions_and_the_unregistered_player() -> void:
	var sim := _game()
	var player := sim.world.player()
	player.job = null
	var retired: Person = null
	for person: Person in sim.world.people.values():
		if person.age_years >= 67:
			retired = person
	_to_monday(sim, 1)
	assert_true(retired.wallet.statement.any(func(e: Dictionary) -> bool: return e["reason"] == "pension" and e["amount"] == content().economy.pension_week))
	assert_false(player.wallet.statement.any(func(e: Dictionary) -> bool: return e["reason"] == "benefit"), "not registered: no benefit")
	assert_eq(Money.held(sim.world), sim.world.ledger.balance())


func test_arrears_and_registration_survive_saving() -> void:
	var sim := _game()
	sim.world.lots[sim.world.player().home_lot_id].arrears = 1234
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		assert_eq(loaded.world.lots[loaded.world.player().home_lot_id].arrears, 1234)
		assert_false(loaded.world.player().benefit_registered)
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v7_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	if old != null:
		assert_false(old.world.player().benefit_registered)
		assert_true(old.world.people.values().any(func(p: Person) -> bool: return p.benefit_registered), "residents are registered")
