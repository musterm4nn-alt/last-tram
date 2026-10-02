extends TestCase
## T-0065: staffed counters. On-site workers stand visibly behind their counters, and counters
## (and the café and pub tables) sell only while someone is serving.

const MONDAY: int = 0
const STAFFED: PackedStringArray = ["buy_snack", "grab_a_beer", "eat_doener", "eat_fries", "buy_groceries", "have_a_drink", "have_a_coffee"]
const BROKEN_INTERACTIONS: String = "res://tests/fixtures/content_broken/interactions/broken.json"
const V11_FIXTURE: String = "res://tests/fixtures/saves/v11_basic.json"


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game on Monday at `hour`. Nobody is at work yet (the clock jumped), everyone counts
## as just having had input, and the player (free will off) stands on the first customer slot
## of the first `def_id` object.
func _game(hour: int, def_id: String) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(MONDAY, hour)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	_stand_on(player, _object(sim, def_id), 0)
	sim.events.drain()
	return sim


func _stand_on(person: Person, obj: WorldObject, slot: int) -> void:
	var cell := obj.slot_cell(content(), slot)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z
	person.path.clear()


func _staff_slot(sim: Sim, obj: WorldObject) -> int:
	for slot: int in obj.slot_count(content()):
		if Interactions.slot_fits(sim, obj.id, slot, content().interaction("work")):
			return slot
	return -1


## The holder of `job_id`'s `position` starts working at the first `def_id` object (standing
## on its staff slot first). Returns them.
func _serve(sim: Sim, job_id: String, position: int, def_id: String) -> Person:
	var worker := Jobs.holder(sim.world, job_id, position)
	worker.free_will = false
	worker.action_queue.clear()
	var counter := _object(sim, def_id)
	_stand_on(worker, counter, _staff_slot(sim, counter))
	sim.submit(QueueInteractionCommand.new(worker.id, "work", counter.id))
	sim.run_minutes(1)
	return worker


func test_on_site_worker_is_visible_behind_the_counter() -> void:
	var sim := _game(12, "spaeti_counter")
	var counter := _object(sim, "spaeti_counter")
	var clerk := _serve(sim, "spaeti_clerk", 0, "spaeti_counter")
	assert_true(Jobs.working(sim, clerk), "the clerk started their shift")
	assert_false(Jobs.hidden(sim, clerk), "on-site work is visible")
	assert_true(WorkSessions.for_job(content().job("spaeti_clerk")) is OnSiteWork)
	var slot := clerk.action_queue[0].slot_index
	assert_eq(clerk.cell(), counter.slot_cell(content(), slot), "behind the counter")
	assert_eq(Vector2i(clerk.facing), counter.slot_facing(content(), slot), "facing the customers")
	assert_true(Conversations.available(sim, clerk), "customers can talk to the clerk")
	var comfort := float(clerk.needs["comfort"])
	sim.run_minutes(60)
	var expected := comfort - content().need("comfort").decay_per_hour + content().job("spaeti_clerk").need_rates["comfort"]
	assert_near(float(clerk.needs["comfort"]), clampf(expected, 0.0, 100.0), 0.2, "needs change like any shift")


func test_rabbit_hole_worker_still_hidden() -> void:
	var sim := _game(9, "tram_stop")
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "work", _object(sim, "tram_stop").id))
	sim.run_minutes(1)
	assert_true(Jobs.working(sim, player))
	assert_true(Jobs.hidden(sim, player), "city jobs still take the tram")
	assert_true(WorkSessions.for_job(content().job("office_clerk")) is RabbitHoleWork)
	assert_false(WorkSessions.for_job(content().job("office_clerk")) is OnSiteWork)


func test_counter_sells_only_while_staffed() -> void:
	var sim := _game(12, "spaeti_counter")
	var player := sim.world.player()
	var counter := _object(sim, "spaeti_counter")
	var snack := content().interaction("buy_snack")
	assert_eq(Requirements.check(sim, player, snack, counter.id), "not_staffed", "open, but nobody is serving")
	assert_eq(Requirements.text("not_staffed"), "nobody's serving")
	sim.submit(QueueInteractionCommand.new(player.id, "buy_snack", counter.id))
	sim.step()
	assert_true(player.action_queue.is_empty(), "refused")
	var clerk := _serve(sim, "spaeti_clerk", 0, "spaeti_counter")
	assert_eq(Requirements.check(sim, player, snack, counter.id), "", "the clerk is serving")
	var cash := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "buy_snack", counter.id))
	sim.run_minutes(6)
	assert_eq(player.wallet.total(), cash - snack.price, "bought a snack")
	sim.submit(CancelActionCommand.new(clerk.id, 0, clerk.action_queue[0].id))
	sim.step()
	assert_false(Jobs.working(sim, clerk))
	assert_eq(Requirements.check(sim, player, snack, counter.id), "not_staffed", "the clerk walked off")
	assert_eq(Requirements.check(sim, player, content().interaction("withdraw_20"), _object(sim, "atm").id), "", "the ATM needs nobody")


func test_a_customer_on_the_way_is_turned_away_when_the_server_leaves() -> void:
	var sim := _game(12, "imbiss_counter")
	var player := sim.world.player()
	var counter := _object(sim, "imbiss_counter")
	player.pos += Vector2(0, 3)
	var cook := _serve(sim, "imbiss_cook", 0, "imbiss_counter")
	sim.submit(QueueInteractionCommand.new(player.id, "eat_fries", counter.id))
	sim.step()
	assert_false(player.action_queue.is_empty(), "accepted while the cook serves")
	sim.submit(CancelActionCommand.new(cook.id, 0, cook.action_queue[0].id))
	var failed: Array = []
	for i: int in 200:
		sim.step()
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"action_failed" and int(event["data"]["person_id"]) == player.id:
				failed.append(event["data"]["reason"])
		if player.action_queue.is_empty():
			break
	assert_eq(failed, ["not_staffed"], "nobody's serving when they get there")


func test_cafe_table_needs_the_barista() -> void:
	var sim := _game(10, "cafe_table")
	var player := sim.world.player()
	var table := _object(sim, "cafe_table")
	var coffee := content().interaction("have_a_coffee")
	assert_eq(Requirements.check(sim, player, coffee, table.id), "not_staffed")
	var barista := _serve(sim, "barista", 0, "cafe_counter")
	assert_true(Jobs.working(sim, barista), "the barista works behind the café counter")
	assert_false(Jobs.hidden(sim, barista))
	assert_eq(Requirements.check(sim, player, coffee, table.id), "", "the tables are served through the café's lot")
	assert_eq(Lots.lot_at(sim, barista.cell()).place_id, "cafe_wolke")


func test_pub_tables_need_the_bartender() -> void:
	var sim := _game(18, "pub_table")
	var player := sim.world.player()
	var table := _object(sim, "pub_table")
	var drink := content().interaction("have_a_drink")
	assert_eq(Requirements.check(sim, player, drink, table.id), "not_staffed")
	_serve(sim, "bartender", 0, "bar_counter")
	assert_eq(Requirements.check(sim, player, drink, table.id), "")


func test_free_will_skips_unstaffed_counter() -> void:
	var sim := _game(12, "imbiss_counter")
	var player := sim.world.player()
	player.needs["hunger"] = 20.0
	var offered := func() -> Array:
		var ids: Array = []
		for option: AutonomyOption in Autonomy.candidates(sim, player):
			ids.append(option.interaction_id)
		return ids
	assert_false(offered.call().has("eat_doener"), "nobody at the Imbiss")
	_serve(sim, "imbiss_cook", 0, "imbiss_counter")
	assert_true(offered.call().has("eat_doener"), "the cook is serving")


func test_staffed_content() -> void:
	for id: String in STAFFED:
		assert_true(content().interaction(id).staffed, id)
	for id: String in ["withdraw_20", "cook_meal", "grab_snack", "sit_outside", "work", "chat"]:
		assert_false(content().interaction(id).staffed, id)
	var barista := content().job("barista")
	assert_true(barista != null, "the barista job exists")
	assert_eq(barista.place_id, "cafe_wolke")
	assert_eq(barista.session, JobDef.ON_SITE)
	assert_eq(Staffing.places(content()), PackedStringArray(["cafe_wolke", "imbiss_anadolu", "kneipe_anker", "spaeti_kaya"]))
	var reader := ContentReader.new()
	InteractionLoader.load_file(ContentDB.load_default(), reader, BROKEN_INTERACTIONS)
	assert_true("\n".join(reader.errors).contains("interaction 'staffed_person': only object-targeted interactions can be staffed"), "\n".join(reader.errors))
	var db := ContentDB.load_default()
	db.jobs.erase("barista")
	var jobs_reader := ContentReader.new()
	JobLoader.check_staffed(db, jobs_reader)
	assert_eq(jobs_reader.errors.size(), 4, "the café's four tables lose their server: %s" % [jobs_reader.errors])
	assert_true("\n".join(jobs_reader.errors).contains("'cafe_table'"), "\n".join(jobs_reader.errors))


func test_every_shop_has_positions_for_all_its_open_hours() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for place_id: String in Staffing.places(content()):
		var lot := Lots.by_place(sim.world, place_id)
		for day: int in SimClock.DAYS_PER_WEEK:
			for hour: int in 24:
				sim.clock.tick = SimClock.ticks_for(day, hour)
				if not Lots.is_open(lot, sim.clock):
					continue
				var covered := false
				for job: JobDef in content().jobs.values():
					for shift: ShiftDef in job.positions if job.place_id == place_id else []:
						covered = covered or _covers(shift, day, hour)
				assert_true(covered, "%s day %d %02d:00 has a position" % [place_id, day, hour])


## True if the shift has someone at work on weekday `day` at `hour` (a shift past midnight
## covers the small hours of the next day).
func _covers(shift: ShiftDef, day: int, hour: int) -> bool:
	if shift.from < shift.to:
		return shift.days.has(day) and hour >= shift.from and hour < shift.to
	return (shift.days.has(day) and hour >= shift.from) or (shift.days.has(posmod(day - 1, SimClock.DAYS_PER_WEEK)) and hour < shift.to)


func test_v11_save_gets_cafe_counter() -> void:
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V11_FIXTURE), content(), errors)
	assert_true(sim != null, "%s" % [errors])
	var counter := _object(sim, "cafe_counter")
	assert_true(counter != null, "Café Wolke has its counter")
	assert_eq(counter.origin, Vector3i(21, 13, 0))
	assert_eq(counter.rotation, 2)
	assert_true(sim.world.new_id() > counter.id, "ids continue after it")
	var migrated := SaveMigrations.migrate(SaveCodec.to_dict(sim).merged({"save_version": 11}, true))
	var counters := 0
	for obj: Dictionary in migrated["world"]["objects"]:
		counters += 1 if obj["def_id"] == "cafe_counter" else 0
	assert_eq(counters, 1, "a save that has one keeps one")
	var room := {"save_version": 11, "world": {"objects": [], "next_id": 5}}
	assert_eq(SaveMigrations.migrate(room)["world"]["objects"], [], "test rooms stay empty")


func test_staffing_report() -> void:
	var sim := _game(12, "spaeti_counter")
	var town := TownCheck.new()
	town.sample(sim)
	assert_eq(town.staffed_share("spaeti_kaya"), 0.0)
	assert_eq(town.staffed_share("kneipe_anker"), 1.0, "never open in the sample")
	assert_true("\n".join(town.staffing_failures(sim)).contains("Späti Kaya was staffed only 0%"))
	_serve(sim, "spaeti_clerk", 0, "spaeti_counter")
	town.sample(sim)
	assert_near(town.staffed_share("spaeti_kaya"), 0.5)
	assert_true(town.staffing_summary(sim).contains("Späti Kaya 50%"), town.staffing_summary(sim))
