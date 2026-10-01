extends TestCase
## T-0032: the HUD's place line says when a business is closed.


func test_place_line_says_closed_outside_opening_hours() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_eq(Hud.place_text(sim, player), "Haus 12, ground floor")
	player.pos = Vector2(4.5, 26.5)
	sim.clock.tick = SimClock.ticks_for(0, 12)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya")
	sim.clock.tick = SimClock.ticks_for(0, 5)
	assert_eq(Hud.place_text(sim, player), "Späti Kaya (closed)")
	player.pos = Vector2(30.5, 30.5)
	assert_eq(Hud.place_text(sim, player), "Altmarkt", "public places never close")


func test_money_text() -> void:
	var sim := SimFactory.new_game(content(), 1)
	assert_eq(Hud.money_text(sim.world.player()), "Cash €40.00 · Bank €300.00")
	assert_eq(Hud.money_text(null), "")
