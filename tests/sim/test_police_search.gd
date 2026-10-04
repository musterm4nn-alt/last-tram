extends TestCase
## T-0095: an officer who loses sight of the suspect searches near where they last saw them,
## then gives up; getting away cools the wanted level off sooner.

const WIDTH: int = 140
const HEIGHT: int = 5


## An open floor WIDTH × HEIGHT with the player at `at`, Monday at noon, no free will.
func _sim(at: Vector2i) -> Sim:
	var rows := PackedStringArray()
	for y: int in HEIGHT:
		var row := ":".repeat(WIDTH)
		if y == at.y:
			row = row.substr(0, at.x) + "@" + row.substr(at.x + 1)
		rows.append(row)
	var sim := SimFactory.from_rows(content(), rows)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	sim.world.player().free_will = false
	sim.events.drain()
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


## A police desk with its origin at `desk` and a morning-shift officer working below it.
func _officer_at_desk(sim: Sim, desk: Vector3i) -> Person:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = "police_desk"
	obj.origin = desk
	sim.world.add_object(obj)
	var officer := _extra(sim, desk + Vector3i(0, 1, 0))
	officer.job = Employment.new()
	officer.job.job_id = Police.JOB_ID
	var action := Action.new("work", obj.id)
	action.id = sim.world.new_id()
	action.state = Action.PERFORMING
	action.slot_index = 2
	action.started_tick = sim.clock.tick
	officer.action_queue.append(action)
	return officer


func _reported(sim: Sim, person_id: int) -> Incident:
	var incident := Incident.new()
	incident.id = sim.world.new_id()
	incident.crime_id = "shoplifting"
	incident.perpetrator_id = person_id
	incident.cell = sim.world.get_person(person_id).cell()
	incident.tick = sim.clock.tick
	incident.reported_by = 99
	incident.reported_tick = sim.clock.tick
	sim.world.incidents[incident.id] = incident
	return incident


func _teleport(person: Person, cell: Vector3i) -> void:
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.level = cell.z


## Runs minute by minute until an event of `type` comes, at most `minutes`. Returns its data
## ({} if none came); other events are dropped.
func _run_until(sim: Sim, type: StringName, minutes: int) -> Dictionary:
	for i: int in minutes:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == type:
				return event["data"]
	return {}


## The player at (30, 4) is reported; the officer at the desk by (1, 0) runs there, but the
## player has slipped away to the far end. Returns the sim once the search has started.
func _searching() -> Sim:
	var sim := _sim(Vector2i(30, 4))
	_officer_at_desk(sim, Vector3i(1, 0, 0))
	_reported(sim, sim.world.player_id)
	sim.run_minutes(1)
	_teleport(sim.world.player(), Vector3i(WIDTH - 1, 0, 0))
	var data := _run_until(sim, &"police_searching", 10)
	assert_eq(int(data.get("person_id", 0)), sim.world.player_id, "the search started")
	return sim


func _officer(sim: Sim) -> Person:
	return sim.world.get_person(sim.world.police_tasks.keys()[0]) if not sim.world.police_tasks.is_empty() else null


func test_out_of_sight_the_officer_searches() -> void:
	var sim := _searching()
	var officer := _officer(sim)
	var task: PoliceTask = sim.world.police_tasks[officer.id]
	assert_eq(task.last_seen, Vector3i(30, 4, 0), "where the crime was reported")
	assert_true(task.search_until > sim.clock.tick)
	assert_false(officer.running, "searching on foot")
	var visited: Dictionary[Vector3i, bool] = {}
	for i: int in 6 * SimClock.STEPS_PER_GAME_MINUTE:
		sim.step()
		var at := officer.cell()
		visited[at] = true
		var radius := content().police_rules.search_radius
		assert_true(maxi(absi(at.x - 30), absi(at.y - 4)) <= radius + 1, "near the spot: %s" % at)
	assert_true(visited.size() > 3, "walks around: %d cells" % visited.size())


func test_seeing_the_suspect_again_resumes_the_chase() -> void:
	var sim := _searching()
	var officer := _officer(sim)
	_teleport(sim.world.player(), officer.cell() + Vector3i(4, 0, 0))
	sim.step()
	var task: PoliceTask = sim.world.police_tasks[officer.id]
	assert_eq(task.search_until, -1, "found")
	assert_true(officer.running)
	var data := _run_until(sim, &"arrested", 2)
	assert_eq(int(data.get("person_id", 0)), sim.world.player_id)


func test_the_officer_gives_up_and_nobody_else_comes() -> void:
	var sim := _searching()
	var officer := _officer(sim)
	var other := _officer_at_desk(sim, Vector3i(100, 0, 0))
	var data := _run_until(sim, &"police_gave_up", content().police_rules.search_minutes + 1)
	assert_eq(int(data.get("officer_id", 0)), officer.id)
	assert_true(sim.world.police_tasks[officer.id].returning, "walks back")
	var incident: Incident = sim.world.incidents.values()[0]
	assert_true(incident.lost_tick >= 0, "lost")
	assert_eq(Police.wanted_level(sim, sim.world.player_id), 1, "still wanted")
	assert_eq(Police.sought_people(sim), [] as Array[int], "but nobody is looking")
	assert_eq(_run_until(sim, &"police_dispatched", 15), {}, "nobody else is sent")
	assert_false(Police.on_call(sim, other))
	assert_false(Police.on_call(sim, officer), "back at the desk")


func test_getting_away_cools_off_sooner() -> void:
	var sim := _sim(Vector2i(30, 4))
	var id := sim.world.player_id
	var incident := _reported(sim, id)
	incident.lost_tick = sim.clock.tick
	assert_eq(Police.wanted_level(sim, id), 1)
	sim.clock.tick += SimClock.ticks_for(0, content().police_rules.lost_heat_hours) - 1
	assert_eq(Police.wanted_level(sim, id), 1, "a moment before lost_heat_hours")
	sim.clock.tick += 1
	assert_eq(Police.wanted_level(sim, id), 0, "after lost_heat_hours, not heat_hours")
	var late := _reported(sim, id)
	late.reported_tick = sim.clock.tick - SimClock.ticks_for(0, content().police_rules.heat_hours - 1)
	late.lost_tick = sim.clock.tick
	sim.clock.tick += SimClock.ticks_for(0, 1)
	assert_eq(Police.wanted_level(sim, id), 0, "never past heat_hours after the report")


func test_a_new_crime_brings_the_police_back() -> void:
	var sim := _searching()
	_run_until(sim, &"police_gave_up", content().police_rules.search_minutes + 1)
	_reported(sim, sim.world.player_id)
	var data := _run_until(sim, &"police_dispatched", 1)
	assert_eq(int(data.get("person_id", 0)), sim.world.player_id)


func test_a_returning_officer_turns_round() -> void:
	var sim := _searching()
	var officer := _officer(sim)
	_run_until(sim, &"police_gave_up", content().police_rules.search_minutes + 1)
	_teleport(sim.world.player(), officer.cell() + Vector3i(5, 0, 0))
	sim.step()
	var spotted := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"police_spotted")
	assert_eq(spotted.size(), 1)
	var task: PoliceTask = sim.world.police_tasks[officer.id]
	assert_false(task.returning)
	assert_true(officer.running)
	assert_eq((sim.world.incidents.values()[0] as Incident).lost_tick, -1, "sought again")
	assert_eq(Police.sought_people(sim), [sim.world.player_id] as Array[int])


func test_running_away_gets_away() -> void:
	var sim := _sim(Vector2i(10, 2))
	var officer := _officer_at_desk(sim, Vector3i(6, 0, 0))
	var player := sim.world.player()
	_reported(sim, player.id)
	sim.run_minutes(1)
	assert_true(Police.on_call(sim, officer), "4 cells away")
	sim.submit(SetRunningCommand.new(player.id, true))
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	sim.run_minutes(2)
	var task: PoliceTask = sim.world.police_tasks[officer.id]
	assert_true(task.last_seen.x > 20, "the officer sees the player and follows: %s" % task.last_seen)
	assert_near(MovementSystem.speed(sim, officer), content().police_rules.officer_run_speed)
	assert_near(MovementSystem.speed(sim, player), player.walk_speed * Person.RUN_FACTOR)
	var data := _run_until(sim, &"police_gave_up", 30)
	assert_eq(int(data.get("person_id", 0)), player.id, "out of sight, out of mind")
	assert_false(player.record, "never caught")


func test_a_search_survives_save_and_load() -> void:
	var sim := _searching()
	var errors: Array[String] = []
	var json := SaveCodec.to_json(sim)
	var loaded := SaveCodec.from_json(json, content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(SaveCodec.to_json(loaded), json)
	for i: int in 14:
		sim.run_minutes(1)
		loaded.run_minutes(1)
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim), "the same search, the same give-up")


func test_bad_search_values_are_rejected() -> void:
	var sim := _searching()
	var d: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	d["world"]["incidents"][0]["lost_tick"] = -5
	d["world"]["police_tasks"][0]["search_until"] = "soon"
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_json(JSON.stringify(d), content(), errors), null)
	var all := "\n".join(errors)
	assert_true(all.contains("world.incidents[].lost_tick"), all)
	assert_true(all.contains("world.police_tasks[].search_until"), all)
