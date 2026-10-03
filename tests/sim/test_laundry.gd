extends TestCase
## T-0074: clothes get dirty, dirty clothes show, the Waschsalon washes them, and how you come
## across counts at interviews.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


func _set_dirt(person: Person, value: float) -> void:
	for slot: String in person.outfit.items:
		person.dirt[Laundry.key(person.outfit.items[slot])] = value


func test_worn_clothes_get_dirty_faster_at_work() -> void:
	var sim := _game()
	var player := sim.world.player()
	var economy := content().economy
	sim.clock.tick = SimClock.ticks_for(1, 12)
	player.free_will = false
	sim.run_minutes(60)
	assert_near(Laundry.worn_dirt(player), economy.dirt_per_hour, 0.01, "an hour awake")
	var top := Laundry.key(player.outfit.get_item("top"))
	var spare: WornItem = null
	for item: WornItem in player.wardrobe:
		var worn := player.outfit.get_item(content().clothing_def(item.clothing_id).slot)
		if worn == null or Laundry.key(worn) != Laundry.key(item):
			spare = item
	assert_eq(float(player.dirt.get(Laundry.key(spare), 0.0)), 0.0, "what's in the wardrobe stays clean")
	Laundry.wash(player)
	sim.clock.tick = SimClock.ticks_for(2, 8, 59)
	var shelter := _object(sim, "tram_stop")
	var cell := shelter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, "work", shelter.id))
	sim.run_minutes(61)
	assert_true(Jobs.working(sim, player))
	assert_near(float(player.dirt[top]), economy.dirt_per_hour + economy.work_dirt_per_hour, 0.1, "an hour at work")


func test_dirty_clothes_show_and_cost_hygiene() -> void:
	var sim := _game()
	var player := sim.world.player()
	sim.clock.tick = SimClock.ticks_for(1, 11, 30)
	_set_dirt(player, 70.0)
	assert_true(Laundry.dirty(sim, player))
	player.needs["hygiene"] = 80.0
	sim.run_minutes(30)
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "dirty_clothes"), "on the hour")
	var decay := content().need("hygiene").decay_per_hour
	assert_near(float(player.needs["hygiene"]), 80.0 - (decay + content().economy.dirty_hygiene_per_hour) / 2.0, 0.05)


func test_washing_cleans_everything_for_four_euros() -> void:
	var sim := _game()
	var player := sim.world.player()
	sim.clock.tick = SimClock.ticks_for(0, 12)
	_set_dirt(player, 90.0)
	var machine := _object(sim, "washing_machine")
	var cell := machine.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	var money := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "wash_clothes", machine.id))
	sim.run_minutes(61)
	assert_true(player.action_queue.is_empty())
	assert_eq(player.wallet.total(), money - 400)
	assert_true(Laundry.worn_dirt(player) < 0.5, "clean (%.2f)" % Laundry.worn_dirt(player))
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "clean_laundry"))
	assert_eq(content().place_at(machine.origin).id, "waschsalon_blitz")


func test_dirty_clothes_send_people_to_the_waschsalon() -> void:
	var sim := _game()
	var resident: Person = null
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id and person.level > 0:
			resident = person
			break
	sim.clock.tick = SimClock.ticks_for(0, 12)
	var wants := func() -> bool:
		return Autonomy.candidates(sim, resident).any(func(o: AutonomyOption) -> bool: return o.interaction_id == "wash_clothes")
	assert_false(wants.call(), "clean clothes: no trip")
	_set_dirt(resident, 80.0)
	assert_true(wants.call(), "dirty: a wash is an errand from upstairs, across town")


func test_presentation_counts_at_interviews() -> void:
	var sim := _game()
	var player := sim.world.player()
	player.needs["hygiene"] = 90.0
	var job := content().job("office_clerk")
	var clean := Presentation.of(sim, player, job.formality)
	var formality := Hiring.outfit_formality(content(), player)
	assert_near(clean, 40.0 / 200.0 - 0.1 * absf(formality - job.formality), 0.0001)
	var chance := Hiring.chance(sim, player, job)
	_set_dirt(player, 50.0)
	assert_near(Presentation.of(sim, player, job.formality), clean - 50.0 / 250.0, 0.0001)
	assert_true(Hiring.chance(sim, player, job) < chance, "dirty clothes cost you the interview")


func test_laundry_survives_saves() -> void:
	var sim := _game()
	_set_dirt(sim.world.player(), 33.25)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	assert_near(Laundry.worn_dirt(loaded.world.player()), 33.25, 0.0001)
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v17_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	assert_true(_object(old, "washing_machine") != null, "old towns get the machines")
