extends TestCase
## T-0073: a second-hand clothes rail and a barber chair at Waschsalon Blitz.


## A new game on `day` at `hour`, the player (free will off) on the first slot of the first
## `def_id` object.
func _at(def_id: String, day: int, hour: int) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour)
	var player := sim.world.player()
	player.free_will = false
	var obj := _object(sim, def_id)
	var cell := obj.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.events.drain()
	return sim


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


func _events(sim: Sim, type: StringName) -> Array:
	return sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == type).map(func(e: Dictionary) -> Dictionary: return e["data"])


func test_the_rail_and_chair_are_in_the_waschsalon() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for def_id: String in ["clothes_rack", "barber_chair"]:
		var obj := _object(sim, def_id)
		assert_true(obj != null, def_id)
		assert_eq(content().place_at(obj.origin).id, "waschsalon_blitz")
		var slot := obj.slot_cell(content(), 0)
		assert_false(sim.nav.find_path(Vector3i(36, 16, 0), slot).is_empty(), def_id + " can be reached from the street")


func test_buying_clothes() -> void:
	var sim := _at("clothes_rack", 0, 12)
	var player := sim.world.player()
	var blazer := content().clothing_def("blazer")
	player.wallet.cash = blazer.price + 100
	player.wallet.bank = 0
	sim.submit(BuyClothesCommand.new(player.id, "blazer", "black"))
	sim.step()
	var bought := _events(sim, &"clothes_bought")
	assert_eq(bought.size(), 1)
	assert_eq(bought[0]["price"], blazer.price)
	assert_true(Wardrobe.owns(player, "blazer", "black"), "it goes into the wardrobe")
	assert_eq(player.wallet.cash, 100, "paid")
	sim.submit(BuyClothesCommand.new(player.id, "blazer", "black"))
	sim.step()
	assert_eq(_events(sim, &"clothes_refused")[0]["reason"], "owned")
	sim.submit(BuyClothesCommand.new(player.id, "leather_jacket", "black"))
	sim.step()
	assert_eq(_events(sim, &"clothes_refused")[0]["reason"], "cant_afford")
	assert_false(Wardrobe.owns(player, "leather_jacket", "black"))
	sim.submit(BuyClothesCommand.new(player.id, "blazer", "neon_pink"))
	sim.step()
	assert_eq(_events(sim, &"clothes_refused")[0]["reason"], "unknown")


func test_the_shop_keeps_its_hours() -> void:
	var sim := _at("clothes_rack", 6, 12)  # Sunday: the Waschsalon is shut
	var player := sim.world.player()
	sim.submit(BuyClothesCommand.new(player.id, "cap", "black"))
	sim.step()
	assert_eq(_events(sim, &"clothes_refused")[0]["reason"], "not_at_shop")
	assert_eq(Requirements.check(sim, player, content().interaction("browse_clothes"), _object(sim, "clothes_rack").id), "closed")
	player.pos = Vector2(50.5, 26.5)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	sim.submit(BuyClothesCommand.new(player.id, "cap", "black"))
	sim.step()
	assert_eq(_events(sim, &"clothes_refused")[0]["reason"], "not_at_shop", "you have to be at the rail")


func test_a_haircut_costs_18_and_changes_your_hair() -> void:
	var sim := _at("barber_chair", 0, 12)
	var player := sim.world.player()
	var money := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "get_haircut", _object(sim, "barber_chair").id))
	sim.run_minutes(31)
	assert_eq(player.wallet.total(), money - 1800)
	var asked := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"screen_requested")
	assert_eq(asked[0]["data"]["screen"], "barber")
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "fresh_cut"))
	var styles: Array = content().appearance.hair_styles.keys()
	var colours: Array = content().appearance.hair_colours.keys()
	var style: String = styles[0] if styles[0] != player.appearance.hair_style else styles[1]
	var colour: String = colours[0] if colours[0] != player.appearance.hair_colour else colours[1]
	sim.submit(ChangeHairCommand.new(player.id, style, colour))
	sim.step()
	assert_eq(player.appearance.hair_style, style)
	assert_eq(player.appearance.hair_colour, colour)
	sim.submit(ChangeHairCommand.new(player.id, "mohawk_of_doom", colour))
	sim.step()
	assert_eq(_events(sim, &"hair_refused").back()["reason"], "unknown")
	player.pos = Vector2(50.5, 26.5)
	sim.submit(ChangeHairCommand.new(player.id, styles[0], colours[0]))
	sim.step()
	assert_eq(_events(sim, &"hair_refused").back()["reason"], "not_at_barber")


func test_old_saves_get_the_rail_and_chair() -> void:
	var errors: Array[String] = []
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v16_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	assert_true(_object(old, "barber_chair") != null)
	assert_true(_object(old, "clothes_rack") != null)
	for type: String in ["buy_clothes", "change_hair"]:
		var command := CommandRegistry.create(type)
		assert_true(command != null and command.type_id() == type, type)
