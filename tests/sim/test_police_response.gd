extends TestCase
## T-0094: a wanted person gets the nearest on-duty police officer, who leaves the desk, runs
## after them, arrests them (a fine, the incidents closed, a record) and walks back.

## The player stands at (23, 4), far out of sight of the desks on the left.
const ROWS: PackedStringArray = [
	"::::::::::::::::::::::::",
	"::::::::::::::::::::::::",
	"::::::::::::::::::::::::",
	"::::::::::::::::::::::::",
	":::::::::::::::::::::::@",
]


## Monday at `hour`, the player without free will and with €30 cash and €200 in the bank.
func _sim(hour: int = 12, minute: int = 0) -> Sim:
	var sim := SimFactory.from_rows(content(), ROWS)
	sim.clock.tick = SimClock.ticks_for(0, hour) + minute * SimClock.STEPS_PER_GAME_MINUTE
	var player := sim.world.player()
	player.free_will = false
	player.wallet.cash = 3000
	player.wallet.bank = 20000
	sim.events.drain()
	return sim


## An adult with starting needs and no free will, standing on `cell`.
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


## A police officer of the morning shift (Mon-Fri 6-14), off duty, standing on `cell`.
func _off_duty_officer(sim: Sim, cell: Vector3i) -> Person:
	var officer := _extra(sim, cell)
	officer.job = Employment.new()
	officer.job.job_id = Police.JOB_ID
	return officer


## A police desk with its origin at `desk`, and an officer working at its first staff slot,
## just below it.
func _officer_at_desk(sim: Sim, desk: Vector3i) -> Person:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = "police_desk"
	obj.origin = desk
	sim.world.add_object(obj)
	var officer := _off_duty_officer(sim, desk + Vector3i(0, 1, 0))
	var action := Action.new("work", obj.id)
	action.id = sim.world.new_id()
	action.state = Action.PERFORMING
	action.slot_index = 2
	action.started_tick = sim.clock.tick
	officer.action_queue.append(action)
	assert_eq(Police.desk_cell(sim, officer), officer.cell(), "standing on the staff slot")
	return officer


## A shoplifting by `person_id` at their feet, reported now.
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


## Runs minute by minute until an event of `type` comes, at most `minutes`. Returns its data
## ({} if none came); every other event is dropped.
func _run_until(sim: Sim, type: StringName, minutes: int) -> Dictionary:
	for i: int in minutes:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == type:
				return event["data"]
	return {}


func test_closed_incidents_dont_count() -> void:
	var sim := _sim()
	var id := sim.world.player_id
	var incident := _reported(sim, id)
	assert_eq(Police.wanted_level(sim, id), 1)
	assert_eq(Police.wanted_people(sim), [id] as Array[int])
	assert_eq(Police.fine_for(sim, id), 2 * content().police_rules.fine_per_severity)
	incident.closed_tick = sim.clock.tick
	assert_eq(Police.wanted_level(sim, id), 0)
	assert_eq(Police.wanted_people(sim), [] as Array[int])
	assert_eq(Police.fine_for(sim, id), 0)


func test_the_nearest_on_duty_officer_is_dispatched() -> void:
	var sim := _sim()
	var far := _officer_at_desk(sim, Vector3i(1, 0, 0))
	var near := _officer_at_desk(sim, Vector3i(10, 0, 0))
	var off_duty := _off_duty_officer(sim, Vector3i(21, 4, 0))
	assert_true(Police.on_duty(sim, near) and Police.on_duty(sim, far))
	assert_false(Police.on_duty(sim, off_duty), "a job but not at work")
	assert_true(Jobs.hidden(sim, near), "at the desk the officer is out of sight")
	_reported(sim, sim.world.player_id)
	var data := _run_until(sim, &"police_dispatched", 1)
	assert_eq(int(data.get("officer_id", 0)), near.id)
	assert_eq(int(data.get("person_id", 0)), sim.world.player_id)
	assert_eq(sim.world.police_tasks.keys(), [near.id])
	var task: PoliceTask = sim.world.police_tasks[near.id]
	assert_eq(task.target_id, sim.world.player_id)
	assert_eq(task.last_seen, sim.world.player().cell(), "heading for the crime")
	assert_true(near.running, "running to the call")
	assert_false(near.path.is_empty())
	assert_true(Police.pursued(sim, sim.world.player_id))
	sim.run_minutes(1)
	assert_eq(sim.world.police_tasks.size(), 1, "one officer is enough")


func test_nobody_comes_without_an_officer_on_duty() -> void:
	var sim := _sim()
	_off_duty_officer(sim, Vector3i(21, 4, 0))
	_reported(sim, sim.world.player_id)
	assert_eq(_run_until(sim, &"police_dispatched", 5), {})
	assert_eq(sim.world.police_tasks.size(), 0)


func test_an_officer_on_a_call_keeps_the_shift() -> void:
	var sim := _sim()
	var officer := _officer_at_desk(sim, Vector3i(1, 0, 0))
	var desk := officer.cell()
	_reported(sim, sim.world.player_id)
	sim.run_minutes(2)
	var cancelled := sim.events.drain().filter(func(e: Dictionary) -> bool:
		return e["type"] in [&"action_cancelled", &"action_failed", &"shift_ended"] and int(e["data"]["person_id"]) == officer.id)
	assert_eq(cancelled, [], "the shift goes on")
	assert_ne(officer.cell(), desk, "out in the street")
	assert_true(Police.on_call(sim, officer))
	assert_true(Jobs.working(sim, officer))
	assert_false(Jobs.hidden(sim, officer), "visible on a call")
	assert_true(officer.job.shift_minutes >= 1, "the call counts as work")


func test_the_officer_catches_and_fines_the_player() -> void:
	var sim := _sim()
	var officer := _officer_at_desk(sim, Vector3i(1, 0, 0))
	var desk := officer.cell()
	var player := sim.world.player()
	var incident := _reported(sim, player.id)
	var data := _run_until(sim, &"arrested", 10)
	assert_eq(int(data.get("person_id", 0)), player.id, "caught within 10 minutes")
	assert_eq(int(data.get("officer_id", 0)), officer.id)
	assert_eq(int(data.get("fine", 0)), 10000, "shoplifting: 2 x €50")
	assert_eq(data.get("incidents", []), [incident.id])
	assert_eq(player.wallet.cash, 0, "cash first")
	assert_eq(player.wallet.bank, 13000, "then the bank")
	assert_eq(sim.world.ledger.sinks.get("fine", 0), 10000)
	assert_true(player.record, "a criminal record")
	assert_true(incident.closed_tick >= 0)
	assert_eq(Police.wanted_level(sim, player.id), 0)
	assert_true(sim.world.police_tasks[officer.id].returning)
	assert_false(officer.running, "walks back")
	sim.run_minutes(10)
	assert_eq(sim.world.police_tasks.size(), 0, "the call is over")
	assert_eq(officer.cell(), desk, "back at the desk")
	assert_true(Jobs.working(sim, officer), "still on shift")
	assert_true(Jobs.hidden(sim, officer))
	assert_eq(_run_until(sim, &"police_dispatched", 3), {}, "nobody is wanted any more")


func test_a_fine_can_overdraw_the_bank() -> void:
	var sim := _sim()
	var officer := _officer_at_desk(sim, Vector3i(1, 0, 0))
	var player := sim.world.player()
	player.wallet.cash = 1000
	player.wallet.bank = 0
	_reported(sim, player.id)
	_reported(sim, player.id)
	var off_ledger := Money.held(sim.world) - sim.world.ledger.balance()  # the test set the wallet by hand
	assert_eq(Police.arrest(sim, officer, player), 20000)
	assert_eq(player.wallet.cash, 0)
	assert_eq(player.wallet.bank, -19000, "a debt")
	assert_eq(Money.held(sim.world) - sim.world.ledger.balance(), off_ledger, "no money made or lost")
	assert_false(Money.fine(sim, player, 0), "nothing to pay")


func test_the_call_ends_with_the_shift() -> void:
	var sim := _sim(13, 58)
	var officer := _officer_at_desk(sim, Vector3i(1, 0, 0))
	_reported(sim, sim.world.player_id)
	sim.run_minutes(1)
	assert_true(Police.on_call(sim, officer))
	sim.run_minutes(3)
	assert_false(Jobs.working(sim, officer), "14:00: the shift is over")
	assert_false(Police.on_call(sim, officer))
	assert_false(officer.running)
	assert_true(officer.path.is_empty(), "stops chasing")


func test_a_chase_survives_save_and_load() -> void:
	var sim := _sim()
	var officer := _officer_at_desk(sim, Vector3i(1, 0, 0))
	_reported(sim, sim.world.player_id)
	sim.run_minutes(1)
	assert_true(Police.on_call(sim, officer))
	var errors: Array[String] = []
	var json := SaveCodec.to_json(sim)
	var loaded := SaveCodec.from_json(json, content(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(SaveCodec.to_json(loaded), json)
	assert_eq(loaded.world.police_tasks[officer.id].to_dict(), sim.world.police_tasks[officer.id].to_dict())
	for i: int in 8:
		sim.run_minutes(1)
		loaded.run_minutes(1)
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim), "the chase goes on the same")
	assert_true(loaded.world.player().record, "caught after loading too")


func test_bad_police_tasks_are_rejected() -> void:
	var sim := _sim()
	var d: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	d["world"]["police_tasks"] = [{"officer_id": 0, "target_id": 1, "last_seen": [1, 2], "returning": "yes"}]
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_json(JSON.stringify(d), content(), errors), null)
	var all := "\n".join(errors)
	for path: String in ["officer_id", "last_seen", "returning"]:
		assert_true(all.contains("world.police_tasks[]." + path), all)


func test_shoplifting_end_to_end() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.run_minutes(40)  # Monday 8:40: the morning officer is at the desk
	var officers := sim.world.people.values().filter(func(p: Person) -> bool: return Police.on_duty(sim, p))
	assert_eq(officers.size(), 1, "one officer on duty")
	var player := sim.world.player()
	player.free_will = false
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "spaeti_counter":
			counter = obj
	var cell := counter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	ShopStaff.serve_now(sim)
	for i: int in 10:
		if Police.wanted_level(sim, player.id) > 0:
			break
		sim.submit(QueueInteractionCommand.new(player.id, "steal_snack", counter.id))
		sim.run_minutes(4)
	assert_true(Police.wanted_level(sim, player.id) > 0, "the clerk called the police")
	sim.events.drain()
	var data := _run_until(sim, &"arrested", 30)
	assert_eq(int(data.get("person_id", 0)), player.id, "the officer came and caught the thief")
	assert_eq(int(data.get("officer_id", 0)), (officers[0] as Person).id)
	assert_true(player.record)
	assert_eq(Police.wanted_level(sim, player.id), 0)
