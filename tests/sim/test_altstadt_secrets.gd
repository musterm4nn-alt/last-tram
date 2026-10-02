extends TestCase
## T-0070: the first eight Altstadt secrets. Each test walks the player from a new game
## through learning the clue the way content intends and uncovering it.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


## Puts `person` on a free cell of `place_id` at Monday + `day`, `hour`:00.
func _at(sim: Sim, person: Person, place_id: String, hour: int, day: int = 1) -> void:
	sim.clock.tick = SimClock.ticks_for(day, hour)
	var cell: Vector3i = Lots.free_cells(sim, content().place(place_id))[0]
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.level = cell.z
	person.path.clear()
	for someone: Person in sim.world.people.values():
		someone.last_input_tick = sim.clock.tick


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## The player does `interaction_id` on the first `def_id` object, starting on its slot.
func _do(sim: Sim, interaction_id: String, def_id: String, minutes: int) -> void:
	var player := sim.world.player()
	var obj := _object(sim, def_id)
	var cell := obj.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	sim.submit(QueueInteractionCommand.new(player.id, interaction_id, obj.id))
	sim.run_minutes(minutes)


## Someone who knows `id` from the start (known_at_start) tells the player when they trust them.
func _told_by_a_local(sim: Sim, id: String) -> Person:
	var def := content().discovery(id)
	var local: Person = null
	for person: Person in Discoveries.people_of(sim, def.known_at_start):
		if person.known_clues.has(id):
			local = person
			break
	assert_true(local != null, "%s: someone at %s knows it from the start" % [id, def.known_at_start])
	if local == null:
		return null
	var player := sim.world.player()
	Social.set_values(local, player.id, {"trust": def.share_trust - 1.0}, sim.clock.tick)
	Discoveries.share_clues(sim, local, player)
	assert_false(player.known_clues.has(id), "%s: not below trust %d" % [id, def.share_trust])
	Social.set_values(local, player.id, {"trust": float(def.share_trust)}, sim.clock.tick)
	Discoveries.share_clues(sim, local, player)
	assert_true(player.known_clues.has(id), "%s: told at trust %d" % [id, def.share_trust])
	return local


func _search_finds(sim: Sim, id: String) -> void:
	var player := sim.world.player()
	var def := content().discovery(id)
	assert_eq(Discoveries.search(sim, player, def.place_id), "found", id)
	assert_true(player.discoveries.has(id), id)


func test_all_eight_secrets_load() -> void:
	var ids: Array = content().discoveries.keys()
	ids.sort()
	assert_eq(ids, ["fountain_coins", "kneipe_cellar", "promenade_alcove", "spati_workbench", "st_nikolai_vestry", "sublet_haus9", "tram_notices", "waschsalon_backroom"])
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	var sim := _game()
	for def_id: String in ["notice_case", "service_board", "vestry_chair"]:
		assert_true(_object(sim, def_id) != null, def_id + " is placed")


func test_fountain_coins() -> void:
	var sim := _game()
	var player := sim.world.player()
	_at(sim, player, "altmarkt", 12)
	assert_eq(Discoveries.search(sim, player, "altmarkt"), "clue", "a look around in the day gives the lead")
	_at(sim, player, "altmarkt", 23)
	var cash := player.wallet.cash
	sim.events.drain()
	_search_finds(sim, "fountain_coins")
	assert_eq(player.wallet.cash, cash + 340)
	assert_true(sim.events.drain().any(func(e: Dictionary) -> bool: return e["type"] == &"scene_requested" and e["data"]["scene_id"] == "coins_at_night"))


func test_tram_notices_lead_to_the_sublet() -> void:
	var sim := _game()
	var player := sim.world.player()
	_at(sim, player, "tram_stop_altmarkt", 12)
	_do(sim, "read_timetable", "notice_case", 6)
	assert_true(player.known_clues.has("tram_notices"), "reading the case gives the lead")
	_at(sim, player, "tram_stop_altmarkt", 12)
	_search_finds(sim, "tram_notices")
	assert_true(player.known_clues.has("sublet_haus9"), "the note points to Haus 9")
	_at(sim, player, "haus_9_stairs_1", 12)
	assert_eq(Discoveries.search(sim, player, "haus_9_stairs_1"), "nothing", "nobody on the stairs at noon")
	_at(sim, player, "haus_9_stairs_1", 19)
	_search_finds(sim, "sublet_haus9")
	for neighbour: Person in Discoveries.people_of(sim, "haus_9_2_flat"):
		assert_true(Social.relationship(player, neighbour.id).familiarity >= Discoveries.CONTACT_FAMILIARITY, "you have their number")


func test_kneipe_cellar() -> void:
	var sim := _game()
	var player := sim.world.player()
	_told_by_a_local(sim, "kneipe_cellar")
	_at(sim, player, "kneipe_anker", 20)
	sim.events.drain()
	_search_finds(sim, "kneipe_cellar")
	assert_true(sim.events.drain().any(func(e: Dictionary) -> bool: return e["type"] == &"scene_requested" and e["data"]["scene_id"] == "the_cellar_door"))


func test_spati_workbench() -> void:
	var sim := _game()
	var player := sim.world.player()
	var local := _told_by_a_local(sim, "spati_workbench")
	_at(sim, player, "hinterhof", 21)
	assert_eq(Discoveries.search(sim, player, "hinterhof"), "nothing", "too dark at 21:00")
	_at(sim, player, "hinterhof", 10)
	_search_finds(sim, "spati_workbench")
	assert_true(Social.relationship(player, local.id).familiarity >= Discoveries.CONTACT_FAMILIARITY)


func test_waschsalon_backroom() -> void:
	var sim := _game()
	var player := sim.world.player()
	_told_by_a_local(sim, "waschsalon_backroom")
	_at(sim, player, "waschsalon_blitz", 21)
	_search_finds(sim, "waschsalon_backroom")


func test_st_nikolai_vestry() -> void:
	var sim := _game()
	var player := sim.world.player()
	_at(sim, player, "church_st_nikolai", 10)
	_do(sim, "read_service_board", "service_board", 6)
	assert_true(player.known_clues.has("st_nikolai_vestry"))
	var chair := _object(sim, "vestry_chair")
	var rest := content().interaction("rest_quietly")
	assert_eq(Requirements.check(sim, player, rest, chair.id), "unknown_secret", "the chair means nothing yet")
	_at(sim, player, "st_nikolai_vestry", 10)
	_search_finds(sim, "st_nikolai_vestry")
	assert_eq(Requirements.check(sim, player, rest, chair.id), "")
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "quiet_moment"))


func test_promenade_alcove() -> void:
	var sim := _game()
	var player := sim.world.player()
	_at(sim, player, "uferweg_alcove", 12)
	var lot := Lots.by_place(sim.world, "uferweg_alcove")
	var alcove := content().interaction("sleep_in_the_alcove")
	assert_eq(Requirements.check(sim, player, alcove, lot.id), "unknown_secret")
	assert_eq(Discoveries.search(sim, player, "uferweg_alcove"), "clue", "a look around in the day")
	_at(sim, player, "uferweg_alcove", 23)
	_search_finds(sim, "promenade_alcove")
	assert_has(Interactions.offered_by_place(sim, player, lot.id), alcove)
	assert_eq(Requirements.check(sim, player, alcove, lot.id), "")
	_at(sim, player, "altmarkt", 23)
	assert_false(Interactions.offered_by_place(sim, player, Lots.by_place(sim.world, "altmarkt").id).has(alcove), "only in the alcove")


func test_locals_know_their_secrets_from_the_start() -> void:
	var sim := _game()
	var knowers := 0
	for person: Person in sim.world.people.values():
		knowers += 1 if not person.known_clues.is_empty() else 0
	assert_true(knowers >= 4, "bartenders, Späti staff and some neighbours know something (%d)" % knowers)
	assert_eq(sim.world.player().known_clues, PackedStringArray(), "the player starts knowing nothing")
