extends TestCase
## T-0092: people who can see a crime remember it and are listed on the incident: same
## floor, in range (shorter at night), awake, and no wall between.

## The player (the thief) stands at (0, 4). A wall runs down x = 5 for rows 0-3; row 4 is open.
const ROWS: PackedStringArray = [
	":::::#::::::",
	":::::#::::::",
	":::::#::::::",
	":::::#::::::",
	"@:::::::::::",
]


func _sim(hour: int) -> Sim:
	var sim := SimFactory.from_rows(content(), ROWS)
	sim.clock.tick = SimClock.ticks_for(0, hour)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


## An extra adult standing on `cell` with starting needs and no free will.
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


func test_who_sees_by_day() -> void:
	var sim := _sim(12)
	var thief := sim.world.player()
	var near := _extra(sim, Vector3i(3, 2, 0))
	var behind_wall := _extra(sim, Vector3i(8, 0, 0))
	var far := _extra(sim, Vector3i(11, 4, 0))
	var down_the_row := _extra(sim, Vector3i(7, 4, 0))
	var seen := Witnesses.find(sim, thief.cell(), thief.id)
	assert_true(seen.has(near.id), "close and in the open")
	assert_true(seen.has(down_the_row.id), "7 cells along the open row")
	assert_false(seen.has(behind_wall.id), "the wall blocks sight")
	assert_false(seen.has(far.id), "11 cells is beyond the day range of 8")
	assert_false(seen.has(thief.id), "not the thief")


func test_the_night_shortens_sight() -> void:
	var sim := _sim(23)
	var thief := sim.world.player()
	var near := _extra(sim, Vector3i(3, 4, 0))
	var down_the_row := _extra(sim, Vector3i(7, 4, 0))
	var seen := Witnesses.find(sim, thief.cell(), thief.id)
	assert_true(seen.has(near.id))
	assert_false(seen.has(down_the_row.id), "7 cells is beyond the night range of 5")


func test_sleepers_and_other_floors_see_nothing() -> void:
	var sim := _sim(12)
	var thief := sim.world.player()
	var sleeper := _extra(sim, Vector3i(2, 4, 0))
	var action := Action.new()
	action.interaction_id = _a_sleep_interaction()
	assert_false(action.interaction_id.is_empty(), "the content has a sleep interaction")
	action.state = Action.PERFORMING
	sleeper.action_queue.append(action)
	var upstairs := _extra(sim, Vector3i(1, 4, 1))
	var seen := Witnesses.find(sim, thief.cell(), thief.id)
	assert_false(seen.has(sleeper.id), "asleep")
	assert_false(seen.has(upstairs.id), "another floor")


func _a_sleep_interaction() -> String:
	for id: String in content().interactions:
		if content().interaction(id).routine == "sleep":
			return id
	return ""


func test_a_crime_gives_witnesses_a_memory_and_lists_them() -> void:
	var sim := _sim(12)
	var thief := sim.world.player()
	var witness := _extra(sim, Vector3i(3, 3, 0))
	var unseen := _extra(sim, Vector3i(9, 1, 0))
	var incident := Crimes.commit(sim, thief, "shoplifting", 0)
	assert_eq(incident.witnesses, PackedInt32Array([witness.id]))
	var memories := Social.memories_about(witness, thief.id)
	assert_eq(memories.size(), 1)
	assert_eq(memories[0].kind, Witnesses.MEMORY_KIND)
	assert_true(memories[0].valence < 0)
	assert_eq(Social.memories_about(unseen, thief.id).size(), 0)
	var events := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"crime_witnessed")
	assert_eq(events.size(), 1)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(loaded.world.incidents[incident.id].witnesses, incident.witnesses)


func test_the_spaeti_clerk_sees_a_snack_pocketed() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var staff := ShopStaff.serve_now(sim)
	var player := sim.world.player()
	player.free_will = false
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "spaeti_counter":
			counter = obj
	var cell := counter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.submit(QueueInteractionCommand.new(player.id, "steal_snack", counter.id))
	sim.run_minutes(4)
	var incident: Incident = Crimes.committed_by(sim, player.id)[0]
	var clerk_saw := false
	for person: Person in staff:
		if incident.witnesses.has(person.id) and Lots.lot_at(sim, person.cell()) == Lots.lot_at(sim, incident.cell):
			clerk_saw = true
	assert_true(clerk_saw, "the Späti clerk on shift saw it (witnesses %s)" % incident.witnesses)
