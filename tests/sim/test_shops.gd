extends TestCase
## T-0056: the Späti and Imbiss counters, the cash machine and Sunday closing.

const SUNDAY: int = 6
const SHOP_INTERACTIONS: Dictionary = {
	"buy_snack": 200, "grab_a_beer": 150, "eat_doener": 600, "eat_fries": 350, "withdraw_20": 0, "withdraw_50": 0,
}


func _object(sim: Sim, def_id: String) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj
	return null


## A new game at `day` (0 = Monday) and `hour` with the shop staff on shift serving (T-0065),
## the player without free will on `slot` of the first `def_id` object.
func _at(def_id: String, day: int, hour: int, slot: int = 0) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour)
	for person: Person in sim.world.people.values():
		person.last_input_tick = sim.clock.tick
	var player := sim.world.player()
	player.free_will = false
	var cell := _object(sim, def_id).slot_cell(content(), slot)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.level = cell.z
	ShopStaff.serve_now(sim)
	sim.events.drain()
	return sim


func _lot(sim: Sim, place_id: String) -> Lot:
	return Lots.by_place(sim.world, place_id)


func test_shop_content_loads_and_every_counter_can_be_reached() -> void:
	for id: String in SHOP_INTERACTIONS:
		var def := content().interaction(id)
		assert_true(def != null, id)
		if def != null:
			assert_eq(def.price, SHOP_INTERACTIONS[id], id)
	assert_eq(content().interaction("withdraw_20").cash_out, 2000)
	assert_eq(content().interaction("withdraw_50").cash_out, 5000)
	var sim := SimFactory.new_game(content(), 1)
	for def_id: String in ["spaeti_counter", "imbiss_counter", "atm"]:
		var obj := _object(sim, def_id)
		assert_true(obj != null, def_id + " is placed")
		var reachable := false
		for slot: int in obj.slot_count(content()):
			if not sim.nav.find_path(Vector3i(20, 27, 0), obj.slot_cell(content(), slot)).is_empty():
				reachable = true
		assert_true(reachable, def_id + " can be reached from the Altmarkt")


func test_a_doener_fills_you_up() -> void:
	var sim := _at("imbiss_counter", 0, 12)
	var player := sim.world.player()
	player.needs["hunger"] = 30.0
	var before := player.wallet.total()
	sim.submit(QueueInteractionCommand.new(player.id, "eat_doener", _object(sim, "imbiss_counter").id))
	sim.run_minutes(21)
	assert_true(player.action_queue.is_empty())
	assert_true(player.needs["hunger"] >= 85.0, "hunger %.1f" % player.needs["hunger"])
	assert_eq(player.wallet.total(), before - 600)
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "good_meal"))


func test_the_atm_turns_bank_money_into_cash() -> void:
	var sim := _at("atm", 0, 12)
	var player := sim.world.player()
	var cash := player.wallet.cash
	var bank := player.wallet.bank
	var balance := sim.world.ledger.balance()
	sim.submit(QueueInteractionCommand.new(player.id, "withdraw_20", _object(sim, "atm").id))
	sim.run_minutes(3)
	assert_eq(player.wallet.cash, cash + 2000)
	assert_eq(player.wallet.bank, bank - 2000)
	assert_eq(sim.world.ledger.balance(), balance, "the ledger doesn't change")


func test_the_atm_needs_money_in_the_bank() -> void:
	var sim := _at("atm", 0, 12)
	var player := sim.world.player()
	Money.charge(sim, player, player.wallet.bank - 1000, "bill")
	sim.events.drain()
	sim.submit(QueueInteractionCommand.new(player.id, "withdraw_20", _object(sim, "atm").id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	var reasons: Array = sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"action_refused").map(func(e: Dictionary) -> String: return e["data"]["reason"])
	assert_eq(reasons, ["cant_afford"], "cash in the pocket doesn't count")


func test_cafe_and_waschsalon_close_on_sunday() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for place_id: String in ["cafe_wolke", "waschsalon_blitz"]:
		var lot := _lot(sim, place_id)
		assert_eq(lot.closed_days, PackedInt32Array([SUNDAY]), place_id)
		sim.clock.tick = SimClock.ticks_for(SUNDAY, 12)
		assert_false(Lots.is_open(lot, sim.clock), place_id + " on Sunday")
		sim.clock.tick = SimClock.ticks_for(7, 12)
		assert_true(Lots.is_open(lot, sim.clock), place_id + " on Monday")
	sim.clock.tick = SimClock.ticks_for(SUNDAY, 12)
	for place_id: String in ["spaeti_kaya", "imbiss_anadolu"]:
		assert_true(Lots.is_open(_lot(sim, place_id), sim.clock), place_id + " opens on Sundays")
	sim.clock.tick = SimClock.ticks_for(SUNDAY, 20)
	assert_true(Lots.is_open(_lot(sim, "kneipe_anker"), sim.clock), "the Kneipe opens on Sundays")


func test_no_coffee_on_sunday() -> void:
	var sim := _at("cafe_table", SUNDAY, 12)
	var player := sim.world.player()
	sim.submit(QueueInteractionCommand.new(player.id, "have_a_coffee", _object(sim, "cafe_table").id))
	sim.step()
	assert_true(player.action_queue.is_empty())
	var refused: Array = sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"action_refused")
	assert_eq(refused.size(), 1)
	assert_eq(refused[0]["data"]["reason"], "closed")
