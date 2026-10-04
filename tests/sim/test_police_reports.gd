extends TestCase
## T-0093: witnesses may report crimes; reported crimes give a wanted level that cools off.

const ROWS: PackedStringArray = [
	"@:::::",
	"::::::",
]


func _sim() -> Sim:
	var sim := SimFactory.from_rows(content(), ROWS)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	sim.world.player().free_will = false
	return sim


func _extra(sim: Sim, cell: Vector3i) -> Person:
	var person := Person.new()
	person.id = sim.world.new_id()
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.free_will = false
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = need_def.start
	sim.world.add_person(person)
	return person


## A reported incident of `crime_id` by `person_id` at the current tick.
func _reported(sim: Sim, person_id: int, crime_id: String) -> Incident:
	var incident := Incident.new()
	incident.id = sim.world.new_id()
	incident.crime_id = crime_id
	incident.perpetrator_id = person_id
	incident.tick = sim.clock.tick
	incident.reported_by = 99
	incident.reported_tick = sim.clock.tick
	sim.world.incidents[incident.id] = incident
	return incident


func test_report_chance_grows_with_severity_and_shrinks_for_friends() -> void:
	var sim := _sim()
	var thief := sim.world.player()
	var witness := _extra(sim, Vector3i(2, 0, 0))
	assert_true(absf(Police.report_chance(sim, witness, thief.id, 2) - 0.5) < 0.0001, "severity 2")
	assert_true(absf(Police.report_chance(sim, witness, thief.id, 8) - 0.95) < 0.0001, "capped at 0.95")
	Social.set_values(witness, thief.id, {"friendship": 60.0}, sim.clock.tick)
	assert_true(absf(Police.report_chance(sim, witness, thief.id, 2) - 0.15) < 0.0001, "a friend")


func test_about_half_of_seen_shopliftings_are_reported() -> void:
	var sim := _sim()
	var thief := sim.world.player()
	_extra(sim, Vector3i(2, 1, 0))
	var reported := 0
	for i: int in 300:
		var incident := Crimes.commit(sim, thief, "shoplifting", 0)
		assert_eq(incident.witnesses.size(), 1)
		if incident.reported_by != 0:
			reported += 1
			assert_eq(incident.reported_tick, sim.clock.tick)
	assert_true(reported > 110 and reported < 190, "reported %d of 300 (expected about 150)" % reported)


func test_unseen_crimes_are_never_reported() -> void:
	var sim := _sim()
	var incident := Crimes.commit(sim, sim.world.player(), "shoplifting", 0)
	assert_eq(incident.witnesses.size(), 0)
	assert_eq(incident.reported_by, 0)
	assert_eq(Police.wanted_level(sim, sim.world.player_id), 0)


func test_wanted_level_sums_reported_crimes_and_cools_off() -> void:
	var sim := _sim()
	var id := sim.world.player_id
	assert_eq(Police.wanted_level(sim, id), 0)
	_reported(sim, id, "shoplifting")
	assert_eq(Police.wanted_level(sim, id), 1, "severity 2 -> level 1")
	_reported(sim, id, "shoplifting")
	_reported(sim, id, "burglary")
	assert_eq(Police.wanted_level(sim, id), 4, "2 + 2 + 4 = 8 -> level 4")
	_reported(sim, id, "assault")
	assert_eq(Police.wanted_level(sim, id), Police.MAX_LEVEL, "capped at 5")
	var unreported := _reported(sim, 12345, "assault")
	unreported.reported_by = 0
	assert_eq(Police.wanted_level(sim, 12345), 0, "unreported crimes don't count")
	sim.clock.tick += SimClock.ticks_for(0, content().police_rules.heat_hours)
	assert_eq(Police.wanted_level(sim, id), 0, "after heat_hours the police lose interest")


func test_reports_survive_save_and_load() -> void:
	var sim := _sim()
	var incident := _reported(sim, sim.world.player_id, "shoplifting")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(loaded.world.incidents[incident.id].reported_by, 99)
	assert_eq(loaded.world.incidents[incident.id].reported_tick, incident.reported_tick)
	assert_eq(Police.wanted_level(loaded, sim.world.player_id), 1)
