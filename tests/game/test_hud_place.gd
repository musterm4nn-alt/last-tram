extends TestCase
## T-0032: the HUD's place line says when a business is closed (and, T-0065, unstaffed).


func test_place_line_says_closed_outside_opening_hours() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_eq(Hud.place_text(sim, player), "Haus 12, ground floor")
	player.pos = Vector2(4.5, 26.5)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	ShopStaff.serve_now(sim)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya")
	sim.clock.tick = SimClock.ticks_for(0, 5)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya (closed, opens 08:00)")
	player.pos = Vector2(30.5, 30.5)
	assert_eq(Hud.place_text(sim, player), "Altmarkt", "public places never close")


func test_money_text() -> void:
	var sim := SimFactory.new_game(content(), 1)
	assert_eq(Hud.money_text(sim.world.player()), "Cash €40.00 · Bank €300.00")
	assert_eq(Hud.money_text(null), "")


func test_place_line_says_closed_on_sunday() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.pos = Vector2(25.5, 13.5)
	sim.clock.tick = SimClock.ticks_for(6, 12)
	assert_eq(Hud.place_text(sim, player), "Café Wolke (closed, opens tomorrow 08:00)")
	sim.clock.tick = SimClock.ticks_for(7, 12)
	ShopStaff.serve_now(sim)
	assert_eq(Hud.place_text(sim, player), "Café Wolke")


func test_closed_places_say_when_they_open() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var cafe := Lots.by_place(sim.world, "cafe_wolke")
	sim.clock.tick = SimClock.ticks_for(5, 20)
	assert_eq(Lots.opening_text(cafe, sim.clock), "opens Mon 08:00", "Saturday evening: Sunday is a closed day")
	sim.clock.tick = SimClock.ticks_for(0, 7)
	assert_eq(Lots.opening_text(cafe, sim.clock), "opens 08:00")
	sim.clock.tick = SimClock.ticks_for(0, 12)
	assert_eq(Lots.opening_text(cafe, sim.clock), "", "open now")
	var kneipe := Lots.by_place(sim.world, "kneipe_anker")
	sim.clock.tick = SimClock.ticks_for(0, 3)
	assert_eq(Lots.opening_text(kneipe, sim.clock), "opens 17:00")


func test_leaving_a_paid_meal_gets_a_notice() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player_id := sim.world.player_id
	var left := {"type": &"action_cancelled", "data": {"person_id": player_id, "interaction_id": "eat_doener", "reason": "moved", "performing": true}}
	assert_eq(Hud.notice_for_event(left, player_id, content(), sim), "Eat a Döner: you left before finishing")
	left["data"]["performing"] = false
	assert_eq(Hud.notice_for_event(left, player_id, content(), sim), "", "nothing paid yet")
	var free := {"type": &"action_cancelled", "data": {"person_id": player_id, "interaction_id": "watch_tv", "reason": "moved", "performing": true}}
	assert_eq(Hud.notice_for_event(free, player_id, content(), sim), "")
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "imbiss_counter":
			counter = obj
	var refused := {"type": &"action_refused", "data": {"person_id": player_id, "interaction_id": "eat_doener", "target_id": counter.id, "reason": "closed"}}
	assert_eq(Hud.notice_for_event(refused, player_id, content(), sim), "Eat a Döner: closed, opens 11:00")


func test_place_text_nobody_serving() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.pos = Vector2(4.5, 26.5)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya (nobody serving)", "open, and the clerk isn't in yet")
	var clerk := Jobs.holder(sim.world, "spaeti_clerk", 0)
	var counter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "spaeti_counter":
			counter = obj
	var action := Action.new("work", counter.id)
	action.state = Action.PERFORMING
	action.started_tick = sim.clock.tick
	clerk.action_queue.clear()
	clerk.action_queue.append(action)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya", "the clerk is serving")
	sim.clock.tick = SimClock.ticks_for(0, 5)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya (closed, opens 08:00)", "closed says closed")
	player.pos = Vector2(30.5, 30.5)
	assert_eq(Hud.place_text(sim, player), "Altmarkt", "nobody serves the square")


## T-0093
func test_wanted_text() -> void:
	assert_eq(Hud.wanted_text(0), "")
	assert_eq(Hud.wanted_text(2), "Wanted ★★☆☆☆")
	assert_eq(Hud.wanted_text(5), "Wanted ★★★★★")
	assert_eq(Hud.notice_for_event({"type": &"crime_reported", "data": {"person_id": 7}}, 7), "Someone called the police on you")
	assert_eq(Hud.notice_for_event({"type": &"crime_reported", "data": {"person_id": 8}}, 7), "")


func test_police_notices() -> void:
	assert_eq(Hud.notice_for_event({"type": &"police_dispatched", "data": {"person_id": 7, "officer_id": 9}}, 7), "The police are looking for you")
	assert_eq(Hud.notice_for_event({"type": &"police_dispatched", "data": {"person_id": 8, "officer_id": 7}}, 7), "", "only the suspect is told")
	assert_eq(Hud.notice_for_event({"type": &"arrested", "data": {"person_id": 7, "officer_id": 9, "fine": 10000}}, 7), "Arrested: fined €100.00. It's on your record now.")
	assert_eq(Hud.notice_for_event({"type": &"arrested", "data": {"person_id": 8, "officer_id": 9, "fine": 10000}}, 7), "")
	assert_eq(Hud.notice_for_event({"type": &"police_searching", "data": {"person_id": 7, "officer_id": 9}}, 7), "The police lost sight of you")
	assert_eq(Hud.notice_for_event({"type": &"police_gave_up", "data": {"person_id": 7, "officer_id": 9}}, 7), "The police gave up looking for you")
	assert_eq(Hud.notice_for_event({"type": &"police_spotted", "data": {"person_id": 7, "officer_id": 9}}, 7), "The police spotted you again")
	assert_eq(Hud.notice_for_event({"type": &"police_gave_up", "data": {"person_id": 8, "officer_id": 7}}, 7), "")
