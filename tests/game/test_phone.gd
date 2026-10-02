extends TestCase
## T-0063: the phone's Bank and Contacts apps, and phone calls.


func test_bank_lines_show_balances_rent_and_the_latest_changes() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	Money.spend(sim, player, 600, "purchase", "eat_doener")
	var lines := BankApp.lines(sim, player.id)
	assert_eq(lines[0], "Cash €34.00")
	assert_eq(lines[1], "Bank €300.00")
	assert_eq(lines[2], "Rent €190.00 + bills €15.00, Mondays")
	assert_true(lines[4].contains("Eat a Döner") and lines[4].ends_with("−€6.00"), lines[4])
	assert_true(lines[lines.size() - 1].contains("Savings"), "the oldest entry last")
	sim.world.lots[player.home_lot_id].arrears = 20500
	sim.world.lots[player.home_lot_id].weeks_behind = 1
	assert_has(BankApp.lines(sim, player.id), "Owed: €205.00 (1 weeks behind)")


func test_statement_entries_in_words() -> void:
	assert_eq(BankApp.entry_text(content(), {"reason": "wage", "detail": "office_clerk"}), "Wages (Office clerk)")
	assert_eq(BankApp.entry_text(content(), {"reason": "rent", "detail": "home_player"}), "Rent")
	assert_eq(BankApp.entry_text(content(), {"reason": "atm", "detail": ""}), "ATM")


func test_contacts_are_people_you_know_best_friends_first() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var others: Array = sim.world.people.keys().filter(func(id: int) -> bool: return id != player.id).slice(0, 3)
	Social.set_values(player, others[0], {"familiarity": 40.0, "friendship": 10.0}, 0)
	Social.set_values(player, others[1], {"familiarity": 60.0, "friendship": 50.0}, 0)
	Social.set_values(player, others[2], {"familiarity": 20.0, "friendship": 90.0}, 0)
	assert_eq(ContactsApp.contacts(sim, player.id), [others[1], others[0]] as Array[int])
	assert_true(ContactsApp.line(sim, player.id, others[1]).begins_with(sim.world.get_person(others[1]).full_name()))


func test_a_call_fills_social_for_both_and_needs_no_walk() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(5, 12)  # Saturday noon: nobody at work
	var player := sim.world.player()
	player.free_will = false
	var friend: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id and person.level != player.level:
			friend = person
			break
	friend.free_will = false
	friend.action_queue.clear()
	friend.path.clear()
	player.needs["social"] = 30.0
	var before := friend.needs["social"]
	sim.submit(CallCommand.new(player.id, friend.id))
	sim.step()
	assert_eq(player.action_queue[0].interaction_id, "phone_call")
	assert_eq(player.action_queue[0].state, Action.PERFORMING, "no walking over")
	sim.run_minutes(21)
	assert_true(player.action_queue.is_empty())
	assert_true(player.needs["social"] > 30.0 + 5.0)
	assert_true(Social.relationship(friend, player.id) != null)
	assert_true(friend.needs["social"] >= before - 2.0, "the call keeps them company too")


func test_nobody_answers_when_asleep_or_at_work() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var worker := Jobs.holder(sim.world, "police_officer", 0)
	sim.clock.tick = SimClock.ticks_for(0, 9)
	var desk: WorldObject = Jobs.workplace(sim, worker)
	var work := Action.new("work", desk.id)
	work.id = sim.world.new_id()
	work.state = Action.PERFORMING
	work.started_tick = sim.clock.tick
	worker.action_queue = [work]
	sim.events.drain()
	sim.submit(CallCommand.new(player.id, worker.id))
	sim.step()
	var failed := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"action_failed" and int(e["data"]["person_id"]) == player.id)
	assert_eq(failed.size(), 1)
	assert_eq(failed[0]["data"]["reason"], "target_busy")


func test_calls_are_not_in_the_person_menu() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var other: int = sim.world.people.keys().filter(func(id: int) -> bool: return id != sim.world.player_id)[0]
	for def: InteractionDef in Interactions.offered_by_person(sim, sim.world.player_id, other):
		assert_false(def.remote, def.id)
