extends TestCase
## T-0066: eviction after unpaid rent, sleeping rough, and moving into empty flats.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.events.drain()
	return sim


## The first resident household (by id) that isn't the player's.
func _household(sim: Sim) -> Household:
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids:
		if id != sim.world.player().household_id:
			return sim.world.households[id]
	return null


func _members(sim: Sim, household: Household) -> Array[Person]:
	var out: Array[Person] = []
	for id: int in household.member_ids:
		out.append(sim.world.get_person(id))
	return out


func _events(sim: Sim, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type:
			out.append(event["data"])
	return out


## Evicts `household` the way three unpaid Mondays would.
func _evict(sim: Sim, household: Household) -> Lot:
	var lot: Lot = sim.world.lots[household.home_lot_id]
	lot.arrears = 50000
	lot.weeks_behind = content().economy.evict_after_weeks
	Moving.evict_overdue(sim)
	return lot


func test_three_unpaid_weeks_evict() -> void:
	var sim := _game()
	var household := _household(sim)
	var lot: Lot = sim.world.lots[household.home_lot_id]
	lot.arrears = 30000
	lot.weeks_behind = content().economy.evict_after_weeks - 1
	Moving.evict_overdue(sim)
	assert_eq(household.home_lot_id, lot.id, "two weeks behind: not yet")
	sim.clock.tick = SimClock.ticks_for(7, 7, 59)
	for person: Person in _members(sim, household):
		person.wallet.bank = 0  # nobody can pay this Monday either
		person.wallet.cash = 0
	sim.events.drain()
	sim.run_minutes(2)
	assert_eq(household.home_lot_id, 0, "the third unpaid Monday evicts")
	assert_eq(lot.arrears, 0, "the debt is written off")
	assert_eq(lot.weeks_behind, 0)
	assert_eq(lot.vacant_since_day, 7)
	assert_eq(household.groceries, 0, "the fridge stays behind")
	for person: Person in _members(sim, household):
		assert_eq(person.home_lot_id, 0)
		assert_true(person.moodlets.any(func(m: Moodlet) -> bool: return m.id == "evicted"), "feels evicted")
		assert_true(person.memories.any(func(m: Memory) -> bool: return m.kind == "evicted"), "remembers it")
	var evicted := _events(sim, &"evicted")
	assert_eq(evicted.size(), 1)
	assert_eq(evicted[0]["household_id"], household.id)
	assert_true(Moving.empty_homes(sim).has(lot))
	assert_true(Moving.homeless(sim).has(household))


func test_homeless_sleep_rough() -> void:
	var sim := _game()
	var household := _household(sim)
	_evict(sim, household)
	var person := _members(sim, household)[0]
	var rough := content().interaction("sleep_rough")
	var bench: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "bench":
			bench = obj
			break
	assert_eq(Requirements.check(sim, person, rough, bench.id), "")
	assert_eq(Requirements.check(sim, sim.world.player(), rough, bench.id), "has_home", "people with a home never sleep rough")
	assert_true(Requirements.HIDDEN.has("has_home"), "and the menu doesn't offer it to them")
	var bed: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id.contains("bed") and lot != null and lot.access == Lot.PRIVATE:
			bed = obj
			break
	assert_eq(Requirements.check(sim, person, content().interaction("sleep"), bed.id), "private", "no bed anywhere")
	# At night, tired and far from the benches, free will still finds one.
	sim.clock.tick = SimClock.ticks_for(1, 23)
	person.needs["energy"] = 15.0
	var options: Array = []
	for option: Dictionary in Autonomy.candidates(sim, person):
		options.append(option["interaction_id"])
	assert_has(options, "sleep_rough")
	assert_false(options.has("sleep"))
	var resident := _members(sim, _household_after(sim, household))[0]
	for option: Dictionary in Autonomy.candidates(sim, resident):
		assert_ne(option["interaction_id"], "sleep_rough", "housed neighbours don't")
	# Sleeping rough is worse than a bed.
	var sleep := content().interaction("sleep")
	assert_true(rough.need_rates["energy"] < sleep.need_rates["energy"])
	assert_true(rough.need_rates["comfort"] < 0.0 and rough.need_rates["hygiene"] < 0.0)


## The next resident household after `household` that still has a home.
func _household_after(sim: Sim, household: Household) -> Household:
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids:
		var other: Household = sim.world.households[id]
		if id > household.id and other.home_lot_id > 0 and id != sim.world.player().household_id:
			return other
	return null


func test_homeless_with_money_move_in() -> void:
	var sim := _game()
	var household := _household(sim)
	var lot := _evict(sim, household)
	sim.events.drain()
	var members := _members(sim, household)
	for person: Person in members:
		person.wallet.bank = 0
	sim.clock.tick = SimClock.ticks_for(sim.clock.day() + 1, 9)
	Moving.daily(sim)
	assert_eq(household.home_lot_id, 0, "no money: still homeless")
	var cost := Moving.move_in_cost(sim, lot)
	assert_eq(cost, content().economy.move_in_weeks * content().place(lot.place_id).rent)
	members[0].wallet.bank = cost
	var offset := Money.held(sim.world) - sim.world.ledger.balance()
	sim.events.drain()
	Moving.daily(sim)
	assert_eq(household.home_lot_id, lot.id, "moved back in with two weeks' rent")
	for person: Person in members:
		assert_eq(person.home_lot_id, lot.id)
	assert_eq(members[0].wallet.bank, 0, "paid up front")
	assert_eq(Money.held(sim.world) - sim.world.ledger.balance(), offset, "the ledger records the rent")
	var moved := _events(sim, &"moved_in")
	assert_eq(moved.size(), 1)
	assert_false(moved[0]["newcomers"])
	assert_eq(lot.vacant_since_day, -1)


func test_empty_flat_gets_newcomers() -> void:
	var sim := _game()
	var household := _household(sim)
	var lot := _evict(sim, household)
	for person: Person in _members(sim, household):
		person.wallet.bank = 0
	var people := sim.world.people.size()
	var offset := Money.held(sim.world) - sim.world.ledger.balance()
	var day := sim.clock.day()
	for d: int in content().economy.vacant_days:
		sim.clock.tick = SimClock.ticks_for(day + d, 10)
		Moving.daily(sim)
		assert_true(Moving.empty_homes(sim).has(lot), "day %d: still empty" % d)
	sim.events.drain()
	sim.clock.tick = SimClock.ticks_for(day + content().economy.vacant_days, 10)
	Moving.daily(sim)
	assert_false(Moving.empty_homes(sim).has(lot), "a week empty: newcomers")
	assert_true(sim.world.people.size() > people)
	var moved := _events(sim, &"moved_in")
	assert_eq(moved.size(), 1)
	assert_true(moved[0]["newcomers"])
	var newcomers: Household = sim.world.households[int(moved[0]["household_id"])]
	assert_eq(newcomers.home_lot_id, lot.id)
	assert_true(newcomers.groceries > 0, "they bring groceries")
	for person: Person in _members(sim, newcomers):
		assert_eq(person.home_lot_id, lot.id)
		assert_true(person.wallet.total() > 0, "and money")
		assert_true(person.age_years >= Person.MIN_AGE)
		assert_true(person.benefit_registered)
		assert_eq(Lots.lot_at(sim, person.cell()), lot, "they arrive in their flat")
	assert_eq(Money.held(sim.world) - sim.world.ledger.balance(), offset, "start money is in the ledger")


func test_player_rents_a_flat() -> void:
	var sim := _game()
	var player := sim.world.player()
	var old: Lot = sim.world.lots[player.home_lot_id]
	var lot := _evict(sim, _household(sim))
	sim.events.drain()
	old.arrears = 1000
	sim.submit(RentFlatCommand.new(player.id, lot.id))
	sim.step()
	var refused := _events(sim, &"rent_flat_refused")
	assert_eq(refused.size(), 1)
	assert_eq(refused[0]["reason"], "owe_rent")
	old.arrears = 0
	player.wallet.bank = Moving.move_in_cost(sim, lot) - 1
	sim.submit(RentFlatCommand.new(player.id, lot.id))
	sim.step()
	assert_eq(_events(sim, &"rent_flat_refused")[0]["reason"], "cant_afford")
	player.wallet.bank = Moving.move_in_cost(sim, lot)
	sim.submit(RentFlatCommand.new(player.id, lot.id))
	sim.step()
	assert_eq(player.home_lot_id, lot.id, "the player moved")
	assert_eq(Groceries.home_household(sim, player).home_lot_id, lot.id)
	assert_true(Moving.empty_homes(sim).has(old), "the old flat is empty now")
	assert_eq(old.vacant_since_day, sim.clock.day())
	sim.submit(RentFlatCommand.new(player.id, lot.id))
	sim.step()
	assert_eq(_events(sim, &"rent_flat_refused").back()["reason"], "not_available", "it's taken: by you")
	var command := CommandRegistry.decode(CommandRegistry.encode(RentFlatCommand.new(player.id, lot.id)))
	assert_true(command is RentFlatCommand and (command as RentFlatCommand).lot_id == lot.id, "replays and saves keep it")


func test_moving_survives_save() -> void:
	var sim := _game()
	var household := _household(sim)
	var lot := _evict(sim, household)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	assert_eq(loaded.world.households[household.id].home_lot_id, 0)
	assert_eq((loaded.world.lots[lot.id] as Lot).vacant_since_day, lot.vacant_since_day)
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	var old := {"save_version": 12, "world": {"lots": [{"id": 3}]}}
	assert_eq(SaveMigrations.migrate(old)["world"]["lots"][0]["vacant_since_day"], -1)
