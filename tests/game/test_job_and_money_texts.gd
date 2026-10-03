extends TestCase
## The words the HUD, menus and inspector use for jobs, money and refusals (moved here from
## tests/sim/ by T-0077: the sim tests check behaviour, these check wording).

const MONDAY: int = 0


func _object(sim: Sim, def_id: String, lot_id: int = -1) -> WorldObject:
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == def_id and (lot_id < 0 or (lot != null and lot.id == lot_id)):
			return obj
	return null


func _game(day: int, hour: int, minute: int = 0) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	return sim


func test_career_notices() -> void:
	assert_eq(Hud.career_notice({"type": &"wages_paid", "data": {"amount": 56000}}, content()), "Payday: €560.00 wages in the bank")
	assert_eq(Hud.career_notice({"type": &"promoted", "data": {"title": "Senior clerk"}}, content()), "Promoted: you're now Senior clerk!")
	assert_eq(Hud.career_notice({"type": &"fired", "data": {"job_id": "office_clerk"}}, content()), "You were fired from your job as Office clerk")
	assert_eq(Hud.career_notice({"type": &"job_warning", "data": {"job_id": "office_clerk"}}, content()), "Your boss warned you about your work (Office clerk)")


func test_application_notices() -> void:
	var data := {"person_id": 1, "job_id": "office_clerk", "position": 0}
	data["reason"] = ""
	assert_eq(Hud.career_notice({"type": &"job_application", "data": data}, content()), "You got the job: Office clerk! You start tomorrow.")
	data["reason"] = "rejected"
	assert_eq(Hud.career_notice({"type": &"job_application", "data": data}, content()), "Office clerk: they chose someone else.")


func test_refused_orders_get_a_notice() -> void:
	var sim := _game(MONDAY, 20)
	var event := {"type": &"action_refused", "data": {"person_id": sim.world.player_id, "interaction_id": "have_a_drink", "reason": "cant_afford"}}
	assert_eq(Hud.notice_for_event(event, sim.world.player_id, content(), sim), "Have a drink: not enough money")
	event["data"]["reason"] = "closed"
	assert_eq(Hud.notice_for_event(event, sim.world.player_id, content(), sim), "Have a drink: closed")


func test_unpaid_rent_notice() -> void:
	var sim := _game(MONDAY, 8)
	var player := sim.world.player()
	var event := {"type": &"rent_unpaid", "data": {"household_id": player.household_id, "lot_id": player.home_lot_id, "owed": 20500, "weeks_behind": 1}}
	assert_eq(Hud.notice_for_event(event, player.id, content(), sim), "Rent: €205.00 unpaid (1 week behind)")


func test_work_reminder_notice() -> void:
	var sim := _game(1, 8)
	var player := sim.world.player()
	var event := {"type": &"work_reminder", "data": {"person_id": player.id, "job_id": "office_clerk", "start_tick": SimClock.ticks_for(1, 9)}}
	assert_eq(Hud.notice_for_event(event, player.id, content(), sim), "Work at 09:00: Office clerk (Tram shelter)")


func test_the_inspector_names_the_job_and_level() -> void:
	var sim := _game(MONDAY, 8)
	var player := sim.world.player()
	player.job.level = 1
	player.job.performance = 60.0
	assert_eq(PersonInspector.job_text(sim, player), "Senior clerk (Mon–Fri 9–17), doing okay")


func test_the_work_menu_shows_shift_and_pay() -> void:
	var sim := _game(MONDAY, 8)
	var shelter := _object(sim, "tram_stop")
	assert_eq(InteractionMenu.entries(sim, shelter.id), ["Tram shelter", "Work (Mon–Fri 9–17, €14.00/h)"])
	assert_eq(InteractionMenu.entries(sim, _object(sim, "police_desk").id), ["Desk", InteractionMenu.NOTHING], "someone else's job isn't shown")
	sim.clock.tick = SimClock.ticks_for(MONDAY, 7, 30)
	assert_eq(InteractionMenu.entries(sim, shelter.id), ["Tram shelter", "Work (Mon–Fri 9–17, €14.00/h) (not your shift)"])


func test_an_empty_fridge_greys_out_cooking_in_the_menu() -> void:
	var sim := _game(MONDAY, 12)
	var player := sim.world.player()
	Groceries.home_household(sim, player).groceries = 1
	assert_eq(InteractionMenu.entries(sim, _object(sim, "stove", player.home_lot_id).id), ["Stove · 1 portion", "Cook a meal (the fridge is empty)"])
	assert_eq(InteractionMenu.entries(sim, _object(sim, "fridge", player.home_lot_id).id), ["Fridge · 1 portion", "Grab a snack"])


func test_housing_app_lines() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_eq(HousingApp.home_lines(sim, player.id)[0], "Your home: Haus 12, ground floor")
	var lot: Lot = sim.world.lots[player.home_lot_id]
	lot.arrears = 19000
	lot.weeks_behind = 1
	assert_has(HousingApp.home_lines(sim, player.id), "Owed: €190.00 (1 weeks behind; evicted at 3)")
	lot.weeks_behind = 3
	Moving.evict_overdue(sim)
	assert_eq(HousingApp.home_lines(sim, player.id), PackedStringArray(["No home. You sleep rough on a bench."]))
	assert_eq(HousingApp.flat_text(sim, lot), "Haus 12, ground floor · €190.00/week · 1 bed · move in €380.00")
	var evicted := {"type": &"evicted", "data": {"household_id": player.household_id, "lot_id": lot.id}}
	assert_eq(Hud.notice_for_event(evicted, player.id, content(), sim), "Evicted: you lost your home at Haus 12, ground floor. Find a flat on the phone.")
	var refused := {"type": &"rent_flat_refused", "data": {"person_id": player.id, "lot_id": lot.id, "reason": "cant_afford"}}
	assert_eq(Hud.notice_for_event(refused, player.id, content(), sim), "Haus 12, ground floor: not enough money in the bank")
	var someone_else := {"type": &"moved_in", "data": {"household_id": -5, "lot_id": lot.id}}
	assert_eq(Hud.notice_for_event(someone_else, player.id, content(), sim), "")


func test_shop_screen_texts() -> void:
	assert_eq(ShopScreen.item_text(content().clothing_def("hoodie")), "Hoodie (outer) · €35.00")
	assert_eq(ShopScreen.stepped(PackedStringArray(["a", "b", "c"]), "c", 1), "a", "wraps")
	assert_eq(ShopScreen.stepped(PackedStringArray(["a", "b", "c"]), "a", -1), "c")
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var bought := {"type": &"clothes_bought", "data": {"person_id": player.id, "item": "cap", "colour": "black", "price": 1500}}
	assert_eq(Hud.notice_for_event(bought, player.id, content(), sim), "Bought: Cap (black), €15.00")
