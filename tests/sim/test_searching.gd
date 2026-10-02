extends TestCase
## T-0068: "Have a look around", learning clues from people and from things you read.


## A new game at `day` `hour`, the player (free will off) standing on the Altmarkt.
func _game(day: int, hour: int) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour)
	var player := sim.world.player()
	player.free_will = false
	player.pos = Vector2(30.5, 30.5)
	player.level = 0
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	sim.events.drain()
	return sim


func _altmarkt(sim: Sim) -> Lot:
	return Lots.by_place(sim.world, "altmarkt")


func _searched(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == &"searched" and int(event["data"]["person_id"]) == sim.world.player_id:
			out.append(event["data"])
	return out


func test_search_finds_a_lead_then_the_secret_at_the_right_time() -> void:
	var sim := _game(0, 12)
	var player := sim.world.player()
	assert_eq(Discoveries.search(sim, player, "altmarkt"), "clue", "no clue yet: the search turns up a lead")
	assert_eq(player.known_clues, PackedStringArray(["fountain_coins"]))
	assert_eq(Discoveries.search(sim, player, "altmarkt"), "nothing", "noon: nothing to find")
	assert_eq(Discoveries.search(sim, player, "kneipe_anker"), "nothing", "wrong place")
	sim.clock.tick = SimClock.ticks_for(0, 23)
	var cash := player.wallet.cash
	assert_eq(Discoveries.search(sim, player, "altmarkt"), "found")
	assert_eq(player.wallet.cash, cash + 340)
	assert_eq(Discoveries.search(sim, player, "altmarkt"), "nothing", "found already")
	var results := _searched(sim).map(func(d: Dictionary) -> String: return d["result"])
	assert_eq(results, ["clue", "nothing", "nothing", "found", "nothing"])


func test_searching_is_an_action_where_you_stand() -> void:
	var sim := _game(0, 23)
	var player := sim.world.player()
	var lot := _altmarkt(sim)
	Discoveries.learn_clue(sim, player, "fountain_coins", "talk")
	sim.events.drain()
	sim.submit(QueueInteractionCommand.new(player.id, "search", lot.id))
	sim.run_minutes(29)
	assert_true(Jobs.working(sim, player) == false and player.action_queue[0].state == Action.PERFORMING, "still looking")
	assert_eq(player.discoveries, PackedStringArray())
	sim.run_minutes(2)
	assert_true(player.action_queue.is_empty())
	assert_eq(player.discoveries, PackedStringArray(["fountain_coins"]), "found the coins after half an hour")
	sim.submit(QueueInteractionCommand.new(player.id, "search", Lots.by_place(sim.world, "kneipe_anker").id))
	sim.step()
	assert_true(player.action_queue.is_empty(), "you can only look around where you are")


func test_walking_away_stops_the_search() -> void:
	var sim := _game(0, 12)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "search", _altmarkt(sim).id))
	sim.run_minutes(5)
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(player.known_clues, PackedStringArray(), "no lead when you leave early")


func test_closed_and_private_places_cant_be_searched() -> void:
	var sim := _game(0, 12)
	var player := sim.world.player()
	var search := content().interaction("search")
	assert_eq(Requirements.check(sim, player, search, Lots.by_place(sim.world, "kneipe_anker").id), "closed")
	var other_home: Lot = null
	for lot: Lot in sim.world.lots.values():
		if lot.access == Lot.PRIVATE and lot.id != player.home_lot_id:
			other_home = lot
			break
	assert_eq(Requirements.check(sim, player, search, other_home.id), "private")
	assert_eq(Requirements.check(sim, player, search, _altmarkt(sim).id), "")


func test_saving_mid_search_continues_identically() -> void:
	var sim := _game(0, 23)
	var player := sim.world.player()
	Discoveries.learn_clue(sim, player, "fountain_coins", "talk")
	sim.submit(QueueInteractionCommand.new(player.id, "search", _altmarkt(sim).id))
	sim.run_minutes(10)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded == null:
		return
	sim.run_minutes(30)
	loaded.run_minutes(30)
	assert_eq(loaded.world.player().discoveries, PackedStringArray(["fountain_coins"]))
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))


func test_people_share_clues_when_they_trust_you() -> void:
	var sim := _game(0, 12)
	var player := sim.world.player()
	var friend: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id:
			friend = person
			break
	Discoveries.learn_clue(sim, friend, "fountain_coins", "search")
	Social.set_values(friend, player.id, {"trust": 10.0}, sim.clock.tick)
	Discoveries.share_clues(sim, friend, player)
	assert_eq(player.known_clues, PackedStringArray(), "trust 10 is below the 20 it takes")
	Social.set_values(friend, player.id, {"trust": 25.0}, sim.clock.tick)
	sim.events.drain()
	Discoveries.share_clues(sim, player, friend)
	assert_eq(player.known_clues, PackedStringArray(["fountain_coins"]), "either side can start the talk")
	var learned := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"clue_learned")
	assert_eq(learned[0]["data"]["source"], "talk")
	assert_eq(learned[0]["data"]["source_id"], friend.id)
	var third: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id and person.id != friend.id:
			third = person
			break
	Discoveries.uncover(sim, friend, "fountain_coins")
	Social.set_values(friend, third.id, {"trust": 50.0}, sim.clock.tick)
	Discoveries.share_clues(sim, friend, third)
	assert_eq(third.known_clues, PackedStringArray(["fountain_coins"]), "what you found you can still tell")


func test_reading_teaches_a_clue() -> void:
	var sim := _game(0, 12)
	var player := sim.world.player()
	var tv: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "tv" and lot != null and lot.id == player.home_lot_id:
			tv = obj
	var watch := content().interaction("watch_tv")
	watch.teaches_clue = "fountain_coins"
	sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
	sim.run_minutes(120)
	watch.teaches_clue = ""
	assert_eq(player.known_clues, PackedStringArray(["fountain_coins"]), "the news mentioned the fountain")
