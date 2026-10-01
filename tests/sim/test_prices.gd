extends TestCase
## T-0055: prices, paying when an action starts, and the shared requirements check.

const BROKEN_PRICES: String = "res://tests/fixtures/content_broken/interactions/prices.json"
## A use slot of the Kneipe's bar counter (the counter is at (47, 8) since T-0059).
const BAR_SLOT: Vector2 = Vector2(47.5, 9.5)


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game at `hour` on Monday, the player without free will standing at `pos`.
func _game(hour: int, pos: Vector2 = BAR_SLOT) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, hour)
	var player := sim.world.player()
	player.free_will = false
	player.pos = pos
	player.level = 0
	sim.events.drain()
	return sim


## Leaves the player with exactly `cents`, spent as purchases.
func _keep(sim: Sim, cents: int) -> void:
	var player := sim.world.player()
	Money.spend(sim, player, player.wallet.total() - cents, "purchase")
	sim.events.drain()


func _events(sim: Sim, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type and int(event["data"].get("person_id", -1)) == sim.world.player_id:
			out.append(event["data"])
	return out


func test_prices_load() -> void:
	assert_eq(content().interaction("have_a_drink").price, 400)
	assert_eq(content().interaction("have_a_coffee").price, 300)
	assert_eq(content().interaction("sit_outside").price, 0)
	var db := ContentDB.load_default()
	var reader := ContentReader.new()
	InteractionLoader.load_file(db, reader, BROKEN_PRICES)
	var all := "\n".join(reader.errors)
	assert_true(all.contains("'negative_price': 'price' must be >= 0"), all)
	assert_true(all.contains("'paid_chat': person-targeted interactions are free"), all)


func test_a_drink_is_paid_when_it_starts() -> void:
	var sim := _game(20)
	var player := sim.world.player()
	var before := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "have_a_drink", _object(sim, "bar_counter").id))
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	assert_eq(player.wallet.total(), before - 400)
	assert_eq(sim.world.ledger.sinks["purchase"], 400)
	var paid := _events(sim, &"money_changed")
	assert_eq(paid.size(), 1)
	assert_eq(paid[0]["reason"], "purchase")
	assert_eq(paid[0]["detail"], "have_a_drink")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		loaded.run_minutes(5)
		assert_eq(loaded.world.player().wallet.total(), before - 400, "a loaded save doesn't charge again")


func test_cannot_queue_what_you_cannot_afford() -> void:
	var sim := _game(20)
	_keep(sim, 200)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "have_a_drink", _object(sim, "bar_counter").id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(player.wallet.total(), 200)
	var refused := _events(sim, &"action_refused")
	assert_eq(refused.size(), 1)
	assert_eq(refused[0]["reason"], "cant_afford")


func test_closed_place_refuses() -> void:
	var sim := _game(10)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "have_a_drink", _object(sim, "bar_counter").id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(_events(sim, &"action_refused")[0]["reason"], "closed")


func test_someone_elses_fridge_is_private() -> void:
	var sim := _game(12)
	var player := sim.world.player()
	var fridge: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "fridge" and lot != null and lot.id != player.home_lot_id:
			fridge = obj
			break
	sim.submit(QueueInteractionCommand.new(player.id, "grab_snack", fridge.id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_eq(_events(sim, &"action_refused")[0]["reason"], "private")
	assert_eq(Requirements.text("private"), "not your home")


func test_money_gone_on_the_way_fails_at_the_start() -> void:
	var sim := _game(20, Vector2(46.5, 12.5))
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "have_a_drink", _object(sim, "bar_counter").id))
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	_keep(sim, 300)
	sim.run_minutes(5)
	assert_true(player.action_queue.is_empty())
	var failed := _events(sim, &"action_failed")
	assert_eq(failed.size(), 1)
	assert_eq(failed[0]["reason"], "cant_afford")
	assert_eq(player.wallet.total(), 300, "nothing charged")


func test_free_will_skips_what_it_cannot_afford() -> void:
	var sim := _game(20)
	var resident: Person = null
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id:
			resident = person
			break
	resident.routine_id = "regular"
	resident.pos = Vector2(46.5, 12.5)
	resident.level = 0
	var offers := func() -> PackedStringArray:
		var ids := PackedStringArray()
		for option: Dictionary in Autonomy.candidates(sim, resident):
			ids.append(String(option["interaction_id"]))
		return ids
	assert_has(offers.call(), "have_a_drink")
	Money.spend(sim, resident, resident.wallet.total(), "purchase")
	assert_false((offers.call() as PackedStringArray).has("have_a_drink"))
	assert_false((offers.call() as PackedStringArray).has("have_a_coffee"))
	assert_has(offers.call(), "sit_outside", "free things are still there")


func test_price_cost_grows_when_money_is_short() -> void:
	var sim := _game(20)
	var player := sim.world.player()
	var drink := content().interaction("have_a_drink")
	_keep(sim, 10000)
	assert_near(Utility.price_cost(player, drink, content()), 0.4)
	_keep(sim, 1000)
	assert_near(Utility.price_cost(player, drink, content()), 3.2)
	assert_eq(Utility.price_cost(player, content().interaction("sit_outside"), content()), 0.0)


func test_refused_orders_get_a_notice() -> void:
	var sim := _game(20)
	var event := {"type": &"action_refused", "data": {"person_id": sim.world.player_id, "interaction_id": "have_a_drink", "reason": "cant_afford"}}
	assert_eq(Hud.notice_for_event(event, sim.world.player_id, content(), sim), "Have a drink: not enough money")
	event["data"]["reason"] = "closed"
	assert_eq(Hud.notice_for_event(event, sim.world.player_id, content(), sim), "Have a drink: closed")
