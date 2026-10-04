extends TestCase
## T-0098: walking into someone else's home, or a shop while it's closed, is trespassing (once
## per visit); "Search for valuables" at their wardrobe is a burglary that takes part of the
## household's savings.


## A new game (seed 1, Monday 8:00), the player without free will.
func _town() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.player().free_will = false
	sim.run_minutes(1)
	sim.events.drain()
	return sim


func _teleport(person: Person, cell: Vector3i) -> void:
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	person.level = cell.z
	person.path.clear()


## A free walkable cell of the place that isn't a doorway.
func _cell_in(sim: Sim, place_id: String) -> Vector3i:
	for cell: Vector3i in Lots.free_cells(sim, content().place(place_id)):
		if not Trespass.doorway(sim, cell):
			return cell
	return Vector3i(-1, -1, -1)


func _object_in(sim: Sim, def_id: String, place_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		var place := content().place_at(obj.origin)
		if obj.def_id == def_id and place != null and place.id == place_id:
			return obj
	return null


func _trespasses(sim: Sim, person_id: int) -> int:
	return Crimes.committed_by(sim, person_id).filter(func(i: Incident) -> bool: return i.crime_id == Trespass.CRIME_ID).size()


func test_burglary_content() -> void:
	var def := content().interaction("burgle")
	assert_eq(def.crime, "burglary")
	assert_true(def.trespass)
	assert_eq(def.object_tags, PackedStringArray(["wardrobe"]))
	var crime := content().crime("burglary")
	assert_eq(crime.steal_account, Money.BANK)
	assert_eq(crime.steal_share, 0.2)
	assert_eq(crime.steal_max, 20000)
	assert_eq(content().crime("pickpocketing").steal_account, Money.CASH)


func test_entering_someone_elses_home_is_trespassing_once_per_visit() -> void:
	var sim := _town()
	var player := sim.world.player()
	_teleport(player, _cell_in(sim, "haus_3"))
	sim.run_minutes(1)
	var mine := Crimes.committed_by(sim, player.id)
	assert_eq(mine.size(), 1)
	assert_eq(mine[0].crime_id, Trespass.CRIME_ID)
	assert_eq(mine[0].lot_id, Lots.by_place(sim.world, "haus_3").id)
	var events := sim.events.drain().filter(func(e: Dictionary) -> bool:
		return e["type"] == &"crime_committed" and e["data"]["crime_id"] == Trespass.CRIME_ID)
	assert_eq(events.size(), 1, "the HUD hears of it (test_hud_place.gd: test_trespass_and_burglary_notices)")
	sim.run_minutes(5)
	assert_eq(_trespasses(sim, player.id), 1, "once per visit")
	_teleport(player, _cell_in(sim, "altmarkt"))
	sim.run_minutes(1)
	_teleport(player, _cell_in(sim, "haus_3"))
	sim.run_minutes(1)
	assert_eq(_trespasses(sim, player.id), 2, "again on the next visit")


func test_own_home_and_open_shops_are_fine() -> void:
	var sim := _town()
	var player := sim.world.player()
	_teleport(player, _cell_in(sim, "home_player"))
	sim.run_minutes(1)
	sim.run_minutes(60)  # 9:01: the Späti is open (8-2)
	_teleport(player, _cell_in(sim, "spaeti_kaya"))
	sim.run_minutes(1)
	assert_eq(_trespasses(sim, player.id), 0)


func test_a_closed_shop_is_off_limits_but_staying_on_is_fine() -> void:
	var sim := _town()
	var player := sim.world.player()
	sim.run_minutes(60)
	var spaeti := Lots.by_place(sim.world, "spaeti_kaya")
	_teleport(player, _cell_in(sim, "spaeti_kaya"))
	sim.run_minutes(1)
	spaeti.closed_days = PackedInt32Array([sim.clock.weekday()])
	assert_false(Lots.is_open(spaeti, sim.clock), "closed now")
	sim.run_minutes(2)
	assert_eq(_trespasses(sim, player.id), 0, "already inside when it closed")
	_teleport(player, _cell_in(sim, "altmarkt"))
	sim.run_minutes(1)
	_teleport(player, _cell_in(sim, "spaeti_kaya"))
	sim.run_minutes(1)
	assert_eq(_trespasses(sim, player.id), 1, "walking into a closed shop")


func test_staff_and_officers_on_a_call_may_go_in() -> void:
	var sim := _town()
	var spaeti := Lots.by_place(sim.world, "spaeti_kaya")
	spaeti.closed_days = PackedInt32Array([sim.clock.weekday()])
	var clerk := Jobs.holder(sim.world, "spaeti_clerk", 0)
	assert_true(clerk != null, "the Späti has a clerk")
	assert_false(Trespass.forbidden(sim, clerk, spaeti), "comes in to work")
	var home := Lots.by_place(sim.world, "haus_3")
	var officer: Person = null
	for person: Person in sim.world.people.values():
		if person.job != null and person.job.job_id == Police.JOB_ID:
			officer = person
	assert_true(Trespass.forbidden(sim, officer, home), "off duty: a private home")
	var call := PoliceTask.new()
	call.officer_id = officer.id
	call.target_id = sim.world.player_id
	sim.world.police_tasks[officer.id] = call
	assert_false(Trespass.forbidden(sim, officer, home), "on a call")


func test_break_ins_only_in_someone_elses_home() -> void:
	var sim := _town()
	var player := sim.world.player()
	var burgle := content().interaction("burgle")
	var theirs := _object_in(sim, "wardrobe", "haus_3")
	var mine := _object_in(sim, "wardrobe", "home_player")
	assert_eq(Requirements.check(sim, player, burgle, theirs.id), "")
	assert_eq(Requirements.check(sim, player, burgle, mine.id), "not_a_break_in", "not at home")
	assert_true(Requirements.HIDDEN.has("not_a_break_in"), "so it isn't even on the menu")
	for def: InteractionDef in Interactions.offered_by(sim, theirs.id):
		if def.id != "burgle":
			assert_eq(Requirements.check(sim, player, def, theirs.id), "private", def.id)


func test_burgling_takes_part_of_the_savings() -> void:
	var sim := _town()
	var player := sim.world.player()
	var wardrobe := _object_in(sim, "wardrobe", "haus_3")
	var victim := Crimes.home_victim(sim, Lots.by_place(sim.world, "haus_3").id)
	assert_true(victim != null and victim.home_lot_id == Lots.by_place(sim.world, "haus_3").id)
	victim.wallet.bank = 50000
	var cash := player.wallet.cash
	_teleport(player, wardrobe.slot_cell(content(), 0))
	sim.submit(QueueInteractionCommand.new(player.id, "burgle", wardrobe.id))
	sim.run_minutes(7)
	var burglaries := Crimes.committed_by(sim, player.id).filter(func(i: Incident) -> bool: return i.crime_id == "burglary")
	assert_eq(burglaries.size(), 1)
	if burglaries.size() == 1:
		assert_eq(burglaries[0].stolen, 10000, "20% of €500")
		assert_eq(burglaries[0].target_id, wardrobe.id)
	assert_eq(victim.wallet.bank, 40000)
	assert_eq(player.wallet.cash, cash + 10000, "into the burglar's pocket")
	victim.wallet.bank = 500000
	var big := Crimes.commit(sim, player, "burglary", wardrobe.id)
	assert_eq(big.stolen, 20000, "at most €200")
	victim.wallet.bank = 0
	assert_eq(Crimes.commit(sim, player, "burglary", wardrobe.id).stolen, 0, "nothing worth taking")


func test_bad_trespass_content_and_saves_are_rejected() -> void:
	var reader := ContentReader.new()
	CrimeLoader.load(ContentDB.new(), reader, "res://tests/fixtures/crimes_broken/bad_account.json")
	assert_true("\n".join(reader.errors).contains("steals_cash account must be"), "\n".join(reader.errors))
	var sim := _town()
	var d: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	d["people"] = d.get("people", [])
	d["world"]["people"][0]["on_lot_id"] = -2
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_json(JSON.stringify(d), content(), errors), null)
	assert_true("\n".join(errors).contains(".on_lot_id"), "\n".join(errors))


func test_walking_through_is_not_trespassing_but_stopping_is() -> void:
	var sim := _town()
	var player := sim.world.player()
	var home := Lots.by_place(sim.world, "haus_3")
	_teleport(player, _cell_in(sim, "haus_3"))
	player.on_lot_id = Lots.by_place(sim.world, "altmarkt").id
	var outside := _cell_in(sim, "altmarkt")
	player.path = sim.nav.find_path(player.cell(), outside)
	assert_true(Trespass.passing_through(sim, player, home))
	Trespass.check(sim)
	assert_eq(_trespasses(sim, player.id), 0, "on the way out")
	player.path.clear()
	Trespass.check(sim)
	assert_eq(_trespasses(sim, player.id), 1, "stopped in someone's flat")


func test_just_after_closing_is_not_trespassing_yet() -> void:
	var sim := _town()
	sim.run_minutes(69)  # Monday 9:10
	var spaeti := Lots.by_place(sim.world, "spaeti_kaya")
	spaeti.open_hour = 0
	spaeti.close_hour = 9
	var player := sim.world.player()
	assert_false(Lots.is_open(spaeti, sim.clock), "closed at 9:00")
	assert_false(Trespass.forbidden(sim, player, spaeti), "10 minutes after closing: still a late customer")
	sim.run_minutes(21)
	assert_true(Trespass.forbidden(sim, player, spaeti), "9:31: off limits")


func test_standing_in_the_doorway_is_not_trespassing() -> void:
	var sim := _town()
	var player := sim.world.player()
	var door := Vector3i(63, 15, 0)
	assert_eq(sim.world.grid.terrain_def_at(door).id, "door")
	assert_eq(content().place_at(door).id, "haus_3")
	_teleport(player, door)
	sim.run_minutes(2)
	assert_eq(_trespasses(sim, player.id), 0, "on the threshold")
	_teleport(player, _cell_in(sim, "haus_3"))
	sim.run_minutes(1)
	assert_eq(_trespasses(sim, player.id), 1, "one step further")
