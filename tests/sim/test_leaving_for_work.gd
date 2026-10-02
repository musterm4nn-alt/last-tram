extends TestCase
## T-0060: shifts as obligations - leaving on time, alarms, reminders; and the habits that keep
## working people well (seeing to needs at home, colleagues).


## A new game moved forward to `day` `hour`:00 (everyone counts as having just had input).
func _game(day: int, hour: int, minute: int = 0) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	sim.events.drain()
	return sim


func _home_cell(sim: Sim, person: Person) -> Vector3i:
	var place := sim.content.place(sim.world.lots[person.home_lot_id].place_id)
	return Lots.free_cells(sim, place)[0]


func _put_home(sim: Sim, person: Person) -> void:
	var cell := _home_cell(sim, person)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z
	person.action_queue.clear()
	person.path.clear()


func _drain(sim: Sim, type: StringName, person_id: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type and int(event["data"].get("person_id", -1)) == person_id:
			out.append(event["data"])
	return out


func test_a_worker_leaves_in_time() -> void:
	var sim := _game(1, 5)
	var officer := Jobs.holder(sim.world, "police_officer", 0)
	_put_home(sim, officer)
	var started: Array[Dictionary] = []
	for minute: int in 70:
		sim.run_minutes(1)
		started.append_array(_drain(sim, &"shift_started", officer.id))
	assert_eq(started.size(), 1, "on shift by 06:10")
	if not started.is_empty():
		assert_true(int(started[0]["late_minutes"]) <= 5, "late %d minutes" % started[0]["late_minutes"])


func test_an_alarm_wakes_a_sleeping_worker() -> void:
	var sim := _game(1, 4)
	var worker := Jobs.holder(sim.world, "police_officer", 0)
	_put_home(sim, worker)
	var bed: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "bed_double" and lot != null and lot.id == worker.home_lot_id:
			bed = obj
	var sleep := Action.new("sleep", bed.id)
	sleep.id = sim.world.new_id()
	worker.action_queue.append(sleep)
	worker.needs["energy"] = 20.0
	var woke := false
	var worked := false
	for minute: int in 130:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if int(event["data"].get("person_id", -1)) != worker.id:
				continue
			woke = woke or event["type"] == &"woke_for_work"
			worked = worked or event["type"] == &"shift_started"
	assert_true(woke, "woken for the 06:00 shift")
	assert_true(worked, "and got there")


func test_the_player_gets_a_reminder_and_free_will_decides() -> void:
	var sim := _game(1, 7, 50)
	var player := sim.world.player()
	player.free_will = false
	_put_home(sim, player)
	sim.run_minutes(11)
	var reminders := _drain(sim, &"work_reminder", player.id)
	assert_eq(reminders.size(), 1, "an hour before 09:00")
	if reminders.size() == 1:
		assert_eq(int(reminders[0]["start_tick"]), SimClock.ticks_for(1, 9))
	sim.run_minutes(60)
	assert_false(WorkSystem._on_the_way(sim, player), "free will off: nobody sends you")
	var idle := _game(1, 8)
	var idler := idle.world.player()
	_put_home(idle, idler)
	idler.last_input_tick = idle.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	idle.run_minutes(60)
	assert_true(Jobs.working(idle, idler) or WorkSystem._on_the_way(idle, idler), "free will on and idle: off to work")
	var busy := _game(1, 8, 40)
	var busy_player := busy.world.player()
	_put_home(busy, busy_player)
	busy.submit(SetMoveIntentCommand.new(busy_player.id, Vector2.ZERO))
	busy.run_minutes(3)
	assert_false(WorkSystem._on_the_way(busy, busy_player), "just pressed a key: left alone")


func test_people_see_to_low_needs_at_home() -> void:
	var sim := _game(1, 12)
	var player := sim.world.player()
	player.job = null
	player.needs["hygiene"] = 30.0
	player.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	player.pos = Vector2(30.5, 30.5)  # out on the Altmarkt
	player.level = 0
	sim.run_minutes(1)
	assert_eq(player.action_queue[0].interaction_id if not player.action_queue.is_empty() else "", "take_shower", "grimy: off home to shower")
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["hygiene"]))
	player.needs["fun"] = 20.0
	player.needs["hunger"] = 25.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["hygiene", "hunger", "fun"]))
	player.needs["fun"] = 10.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["fun", "hygiene", "hunger"]), "below its critical level, fun comes first")


func test_critical_needs_come_before_routine_ones() -> void:
	var sim := _game(1, 12)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	player.needs["hygiene"] = 44.0
	player.needs["hunger"] = 1.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["hunger", "hygiene"]), "starving beats grimy")
	player.needs["energy"] = 5.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["hunger", "energy", "hygiene"]), "critical ones lowest first")


func test_an_empty_fridge_sends_people_to_the_shops() -> void:
	var sim := _game(1, 12)
	ShopStaff.serve_now(sim)
	var player := sim.world.player()
	player.job = null
	Groceries.home_household(sim, player).groceries = 0
	player.needs["hunger"] = 20.0
	player.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	_put_home(sim, player)
	sim.run_minutes(1)
	assert_false(player.action_queue.is_empty())
	if not player.action_queue.is_empty():
		var def := content().interaction(player.action_queue[0].interaction_id)
		assert_true(def.price > 0 and def.advertise.has("hunger"), "off to buy food: %s" % def.id)


func test_colleagues_get_to_know_each_other() -> void:
	var sim := _game(0, 8, 50)
	var player := sim.world.player()
	var colleague: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id and person.job != null and person.job.job_id == "office_clerk":
			colleague = person
	if colleague == null:
		colleague = sim.world.people.values()[1]
		colleague.job = null
		Jobs.hire(sim, colleague, "office_clerk", 2 if Jobs.holder(sim.world, "office_clerk", 2) == null else 1)
	player.free_will = false
	var shelter: WorldObject = Jobs.workplace(sim, player)
	var cell := shelter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, "work", shelter.id))
	sim.run_minutes(8 * 60 + 15)
	var r := Social.relationship(player, colleague.id)
	assert_true(r != null and r.familiarity >= content().economy.colleague_deltas["familiarity"], "a shift together")


func test_leaving_for_work_drops_an_npcs_plans_but_keeps_the_players() -> void:
	var sim := _game(1, 12)
	var officer := Jobs.holder(sim.world, "police_officer", 0)
	var player := sim.world.player()
	for person: Person in [officer, player]:
		_put_home(sim, person)
		for interaction_id: String in ["watch_tv", "take_shower", "grab_snack"]:
			var action := Action.new(interaction_id, 0)
			action.id = sim.world.new_id()
			person.action_queue.append(action)
		WorkSystem._go(sim, person)
	var ids := func(person: Person) -> Array: return person.action_queue.map(func(a: Action) -> String: return a.interaction_id)
	assert_eq(ids.call(officer), ["work"], "an NPC's later plans are stale after a shift")
	assert_eq(ids.call(player), ["work", "take_shower", "grab_snack"], "the player's queue stays, minus the front")


func test_only_colleagues_who_turned_up_count() -> void:
	var sim := _game(0, 17, 5)
	var player := sim.world.player()
	var others: Array[Person] = []
	for person: Person in sim.world.people.values():
		if person.id != player.id and others.size() < 2:
			others.append(person)
	var there := others[0]
	var absent := others[1]
	var shift_start := SimClock.ticks_for(0, 9)
	for person: Person in others:
		person.job = Employment.new()
		person.job.job_id = "office_clerk"
		person.relationships.clear()
	player.relationships.clear()
	there.job.last_shift_start = shift_start
	Jobs.know_colleagues(sim, player, shift_start)
	assert_true(Social.relationship(player, there.id) != null, "worked the same day")
	assert_true(Social.relationship(player, absent.id) == null, "on the rota but never came")
	absent.job.shift_start = shift_start
	absent.job.shift_minutes = 30
	Jobs.know_colleagues(sim, player, shift_start)
	assert_true(Social.relationship(player, absent.id) != null, "working it right now")


func test_supper_before_bed() -> void:
	var sim := _game(1, 12)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	player.needs["hunger"] = 50.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(), "midday: 50 is fine")
	sim.clock.tick = SimClock.ticks_for(1, 23)
	assert_true(Routines.sleeping_time(sim, player))
	assert_eq(Routines.home_needs(sim, player), PackedStringArray(["hunger"]), "bedtime: eat first, don't wake up starving")
	player.needs["hunger"] = 60.0
	assert_eq(Routines.home_needs(sim, player), PackedStringArray())
