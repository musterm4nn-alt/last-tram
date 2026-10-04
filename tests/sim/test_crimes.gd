extends TestCase
## T-0091: crimes are content, an interaction can commit one, and each crime committed is
## saved as an incident.


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game on Monday at noon, the player without free will at the Späti counter.
func _at_spaeti() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	var cell := _object(sim, "spaeti_counter").slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.events.drain()
	return sim


func test_crime_content_loads() -> void:
	assert_eq(content().crime("shoplifting").severity, 2)
	assert_eq(content().crime("burglary").severity, 4)
	assert_eq(content().crime("nonsense"), null)
	assert_eq(content().police_rules.fine_per_severity, 5000, "T-0094")
	assert_eq(content().police_rules.arrest_range, 1.0)
	assert_eq(content().interaction("steal_snack").crime, "shoplifting")
	assert_eq(content().interaction("buy_snack").crime, "")


func test_stealing_a_snack_is_free_and_recorded() -> void:
	var sim := _at_spaeti()
	var player := sim.world.player()
	player.needs["hunger"] = 40.0
	var before := player.wallet.total()
	var counter := _object(sim, "spaeti_counter")
	sim.submit(QueueInteractionCommand.new(player.id, "steal_snack", counter.id))
	sim.run_minutes(4)
	assert_true(player.action_queue.is_empty())
	assert_eq(player.wallet.total(), before, "no money changes hands")
	assert_true(player.needs["hunger"] > 50.0, "hunger %.1f" % player.needs["hunger"])
	var mine := Crimes.committed_by(sim, player.id)
	assert_eq(mine.size(), 1)
	var incident := mine[0]
	assert_eq(incident.crime_id, "shoplifting")
	assert_eq(incident.target_id, counter.id)
	assert_eq(incident.cell, player.cell())
	assert_eq(incident.lot_id, Lots.lot_at(sim, player.cell()).id, "the Späti lot")
	assert_true(incident.tick > SimClock.ticks_for(0, 12))
	var events := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"crime_committed")
	assert_eq(events.size(), 1)
	assert_eq(int(events[0]["data"]["incident_id"]), incident.id)


func test_incidents_survive_save_and_load() -> void:
	var sim := _at_spaeti()
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "steal_snack", _object(sim, "spaeti_counter").id))
	sim.run_minutes(4)
	var errors: Array[String] = []
	var json := SaveCodec.to_json(sim)
	var loaded := SaveCodec.from_json(json, content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(loaded.world.incidents.size(), 1)
	var a: Incident = sim.world.incidents.values()[0]
	var b: Incident = loaded.world.incidents.values()[0]
	assert_eq(b.to_dict(), a.to_dict())
	assert_eq(SaveCodec.to_json(loaded), json)


func test_old_saves_load_with_no_incidents() -> void:
	var errors: Array[String] = []
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v19_basic.json"), content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_true(old != null)
	if old != null:
		assert_eq(old.world.incidents.size(), 0)


func test_bad_incidents_are_rejected() -> void:
	var sim := _at_spaeti()
	var d: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	d["world"]["incidents"] = [{"id": 5, "crime_id": "shoplifting", "perpetrator_id": 1, "target_id": 0, "cell": [1, 2], "lot_id": 0, "tick": -3}]
	var errors: Array[String] = []
	SaveCodec.from_json(JSON.stringify(d), content(), errors)
	var text := "\n".join(errors)
	assert_true(text.contains("world.incidents[].cell"), text)
	assert_true(text.contains("world.incidents[].tick"), text)


func test_free_will_never_steals() -> void:
	var sim := SimFactory.new_game(content(), 2)
	sim.run_minutes(24 * 60)
	assert_eq(sim.world.incidents.size(), 0)


func test_police_numbers_are_validated() -> void:
	var reader := ContentReader.new()
	CrimeLoader.load(ContentDB.new(), reader, "res://tests/fixtures/crimes_broken/bad_police.json")
	var all := "\n".join(reader.errors)
	assert_true(all.contains("fine_per_severity must be 0 or more and arrest_range 0.5 to 3"), all)
