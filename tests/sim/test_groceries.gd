extends TestCase
## T-0057: household groceries - cooking uses portions, the Späti sells them, free will shops.


func _object_in(sim: Sim, def_id: String, lot_id: int) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == def_id and lot != null and lot.id == lot_id:
			return obj
	return null


func _first(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game at Monday `hour`; the player without free will stands on the object's slot.
func _at(obj_def: String, hour: int, home_only: bool = true) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, hour)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	var obj := _object_in(sim, obj_def, player.home_lot_id) if home_only else _first(sim, obj_def)
	var cell := obj.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.events.drain()
	return sim


func _home(sim: Sim) -> Household:
	return Groceries.home_household(sim, sim.world.player())


func _refusals(sim: Sim) -> Array:
	return sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"action_refused").map(func(e: Dictionary) -> String: return e["data"]["reason"])


func test_cooking_uses_portions() -> void:
	var sim := _at("stove", 12)
	var player := sim.world.player()
	_home(sim).groceries = 5
	sim.submit(QueueInteractionCommand.new(player.id, "cook_meal", _object_in(sim, "stove", player.home_lot_id).id))
	sim.step()
	assert_eq(_home(sim).groceries, 3, "a meal uses two portions when it starts")
	sim.run_minutes(31)
	var fridge := _object_in(sim, "fridge", player.home_lot_id)
	var cell := fridge.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, "grab_snack", fridge.id))
	sim.step()
	assert_eq(_home(sim).groceries, 2, "a snack uses one")


func test_an_empty_fridge_greys_out_cooking() -> void:
	var sim := _at("stove", 12)
	var player := sim.world.player()
	_home(sim).groceries = 1
	var stove := _object_in(sim, "stove", player.home_lot_id)
	sim.submit(QueueInteractionCommand.new(player.id, "cook_meal", stove.id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(_refusals(sim), ["no_food"])


func test_buying_groceries_fills_the_fridge() -> void:
	var sim := _at("spaeti_counter", 12, false)
	var player := sim.world.player()
	_home(sim).groceries = 3
	var money := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "buy_groceries", _first(sim, "spaeti_counter").id))
	sim.run_minutes(6)
	assert_eq(_home(sim).groceries, 9)
	assert_eq(player.wallet.total(), money - 900)


func test_a_full_fridge_refuses_more() -> void:
	var sim := _at("spaeti_counter", 12, false)
	var player := sim.world.player()
	_home(sim).groceries = content().economy.fridge_capacity - 5
	sim.submit(QueueInteractionCommand.new(player.id, "buy_groceries", _first(sim, "spaeti_counter").id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(_refusals(sim), ["fridge_full"])


## A resident at home at Monday 12:00 with `portions` in the fridge and this hunger.
func _resident(sim: Sim, portions: int, hunger: float) -> Person:
	for person: Person in sim.world.people.values():
		var home := Groceries.home_household(sim, person)
		if person.id != sim.world.player_id and home != null and person.level > 0:
			home.groceries = portions
			person.needs["hunger"] = hunger
			return person
	return null


func _options(sim: Sim, person: Person) -> PackedStringArray:
	var ids := PackedStringArray()
	for option: Dictionary in Autonomy.candidates(sim, person):
		ids.append(String(option["interaction_id"]))
	return ids


func test_low_stock_sends_people_shopping() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	var person := _resident(sim, 2, 90.0)
	assert_has(_options(sim, person), "buy_groceries", "a low fridge: shopping from upstairs, across town")
	Groceries.home_household(sim, person).groceries = 12
	assert_false(_options(sim, person).has("buy_groceries"), "no hoarding")


func test_hungry_people_with_empty_fridges_eat_out() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	var person := _resident(sim, 0, 30.0)
	var options := _options(sim, person)
	assert_has(options, "eat_doener")
	assert_has(options, "buy_snack")
	person.needs["hunger"] = 80.0
	assert_false(_options(sim, person).has("eat_doener"), "not hungry: no trip to the Imbiss")
	person.needs["hunger"] = 30.0
	Groceries.home_household(sim, person).groceries = 6
	assert_false(_options(sim, person).has("eat_doener"), "food at home: cook instead")


func test_groceries_are_saved_and_start_in_range() -> void:
	var sim := SimFactory.new_game(content(), 2)
	var range_ := content().economy.start_groceries
	for household: Household in sim.world.households.values():
		assert_true(household.groceries >= range_.x and household.groceries <= range_.y)
	var again := SimFactory.new_game(content(), 2)
	for id: int in sim.world.households:
		assert_eq(again.world.households[id].groceries, sim.world.households[id].groceries)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		for id: int in sim.world.households:
			assert_eq(loaded.world.households[id].groceries, sim.world.households[id].groceries)


func test_older_saves_get_ten_portions() -> void:
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v4_basic.json"), content(), errors)
	assert_true(sim != null, "%s" % [errors])
	if sim != null:
		assert_false(sim.world.households.is_empty())
		for household: Household in sim.world.households.values():
			assert_eq(household.groceries, 10)
