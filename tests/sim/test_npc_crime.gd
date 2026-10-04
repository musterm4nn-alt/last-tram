extends TestCase
## T-0097: dishonest or broke residents commit crimes on their own when nobody is watching,
## at most once every cooldown_hours, and never while wanted.

const ROWS: PackedStringArray = [
	"@:::::::::::::::::::",
	"::::::::::::::::::::",
	"::::::::::::::::::::",
]


func _sim() -> Sim:
	var sim := SimFactory.from_rows(content(), ROWS)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


## A resident on `cell` with full needs, €100 in the bank and the given honesty.
func _resident(sim: Sim, cell: Vector3i, honesty: int = 0) -> Person:
	var person := Person.new()
	person.id = sim.world.new_id()
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.free_will = false
	person.wallet.bank = 10000
	person.personality.set_axis("honesty", honesty)
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 100.0
	sim.world.add_person(person)
	return person


func _incident(sim: Sim, person_id: int, tick: int) -> Incident:
	var incident := Incident.new()
	incident.id = sim.world.new_id()
	incident.crime_id = "pickpocketing"
	incident.perpetrator_id = person_id
	incident.tick = tick
	sim.world.incidents[incident.id] = incident
	return incident


func test_temptation_content() -> void:
	var rules := content().temptation_rules
	assert_eq(rules.honesty_below, -40)
	assert_eq(rules.cooldown_hours, 72)
	assert_eq(content().interaction("steal_snack").advertise.get("hunger", 0.0), 15.0, "it feeds")
	var reader := ContentReader.new()
	CrimeLoader.load(ContentDB.new(), reader, "res://tests/fixtures/crimes_broken/bad_temptation.json")
	assert_true("\n".join(reader.errors).contains("temptation needs cooldown_hours 1 or more"), "\n".join(reader.errors))


func test_who_is_willing() -> void:
	var sim := _sim()
	var honest := _resident(sim, Vector3i(5, 1, 0), 0)
	var crook := _resident(sim, Vector3i(6, 1, 0), -60)
	var broke := _resident(sim, Vector3i(7, 1, 0), 0)
	broke.wallet.bank = 500
	assert_false(Temptation.willing(sim, honest), "honest and not broke")
	assert_true(Temptation.willing(sim, crook), "dishonest")
	assert_true(Temptation.willing(sim, broke), "broke")
	sim.world.player().personality.set_axis("honesty", -100)
	assert_false(Temptation.willing(sim, sim.world.player()), "the player decides for the player")
	var recent := _incident(sim, crook.id, sim.clock.tick - SimClock.ticks_for(0, 71))
	assert_false(Temptation.willing(sim, crook), "lies low after a crime")
	recent.tick = sim.clock.tick - SimClock.ticks_for(0, 72)
	assert_true(Temptation.willing(sim, crook), "after cooldown_hours")
	recent.reported_by = 99
	recent.reported_tick = sim.clock.tick
	assert_false(Temptation.willing(sim, crook), "not while wanted")


func test_risk_counts_witnesses_officers_and_bravery() -> void:
	var sim := _sim()
	var crook := _resident(sim, Vector3i(10, 1, 0), -60)
	var at := Vector3i(12, 1, 0)
	_teleport_player_away(sim)
	assert_near(Temptation.risk(sim, crook, at), 0.0, 0.001, "nobody near")
	_teleport(sim.world.player(), Vector3i(14, 2, 0))
	assert_near(Temptation.risk(sim, crook, at), 3.0, 0.001, "the player can see")
	var victim := _resident(sim, Vector3i(13, 1, 0))
	assert_near(Temptation.risk(sim, crook, at, victim.id), 3.0, 0.001, "the victim doesn't count")
	assert_near(Temptation.risk(sim, crook, at), 6.0, 0.001, "two onlookers")
	crook.personality.set_axis("bravery", 100)
	assert_near(Temptation.risk(sim, crook, at), 3.0, 0.001, "the brave mind half as much")
	crook.personality.set_axis("bravery", 0)
	victim.job = Employment.new()
	victim.job.job_id = Police.JOB_ID
	var desk := WorldObject.new()
	desk.id = sim.world.new_id()
	desk.def_id = "police_desk"
	desk.origin = Vector3i(15, 0, 0)
	sim.world.add_object(desk)
	var work := Action.new("work", desk.id)
	work.state = Action.PERFORMING
	work.slot_index = 2
	work.started_tick = sim.clock.tick
	victim.action_queue.append(work)
	var call := PoliceTask.new()
	call.officer_id = victim.id
	call.target_id = 12345
	sim.world.police_tasks[victim.id] = call
	assert_near(Temptation.risk(sim, crook, at), 16.0, 0.001, "an officer on a call: 3 + 10, plus the player")


func test_a_crook_picks_a_pocket_only_when_nobody_watches() -> void:
	var sim := _sim()
	_teleport_player_away(sim)
	var crook := _resident(sim, Vector3i(10, 1, 0), -80)
	var victim := _resident(sim, Vector3i(12, 1, 0))
	victim.wallet.cash = 2000
	crook.free_will = true
	sim.run_minutes(10)
	var mine := Crimes.committed_by(sim, crook.id)
	assert_eq(mine.size(), 1, "tempted, unseen: one pickpocketing")
	if mine.size() == 1:
		assert_eq(mine[0].crime_id, "pickpocketing")
		assert_eq(mine[0].target_id, victim.id)
	sim.run_minutes(60)
	assert_eq(Crimes.committed_by(sim, crook.id).size(), 1, "then lies low")


func test_a_crook_leaves_pockets_alone_with_someone_watching() -> void:
	var sim := _sim()
	var crook := _resident(sim, Vector3i(10, 1, 0), -80)
	var victim := _resident(sim, Vector3i(12, 1, 0))
	victim.wallet.cash = 2000
	_teleport(sim.world.player(), Vector3i(14, 2, 0))
	crook.free_will = true
	sim.run_minutes(10)
	assert_eq(Crimes.committed_by(sim, crook.id).size(), 0, "the player is watching")


func test_broke_and_hungry_residents_may_shoplift() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.run_minutes(60)  # Monday 9:00: the Späti is open
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "spaeti_counter":
			counter = obj
	var resident: Person = null
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id and person.job == null and person.personality.get_axis("honesty") > -40:
			resident = person
			break
	_teleport(resident, counter.slot_cell(content(), 0))
	resident.needs["hunger"] = 10.0
	var options := func() -> PackedStringArray:
		var ids := PackedStringArray()
		for option: AutonomyOption in Autonomy.candidates(sim, resident):
			ids.append(option.interaction_id)
		return ids
	assert_false(options.call().has("steal_snack"), "an honest resident with money pays")
	Money.spend(sim, resident, resident.wallet.total(), "purchase")
	assert_true(options.call().has("steal_snack"), "broke and hungry")


func test_the_crime_report_line() -> void:
	var sim := _sim()
	var crook := _resident(sim, Vector3i(5, 1, 0), -60)
	var a := _incident(sim, crook.id, sim.clock.tick)
	a.stolen = 1250
	a.reported_by = 99
	a.closed_tick = sim.clock.tick
	var b := _incident(sim, sim.world.player_id, sim.clock.tick)
	b.crime_id = "shoplifting"
	b.lost_tick = sim.clock.tick
	assert_eq(CrimeReport.line(sim, 2), "crime: 2 in 2 days (1.0 a day): shoplifting 1, pickpocketing 1 | by residents 1 | reported 1, charged 1, escaped 1 | fines €0.00, stolen €12.50")


func _teleport(person: Person, cell: Vector3i) -> void:
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.level = cell.z


## The player stays out of sight in the far corner (more than 8 cells from the others).
func _teleport_player_away(sim: Sim) -> void:
	_teleport(sim.world.player(), Vector3i(0, 0, 0))
