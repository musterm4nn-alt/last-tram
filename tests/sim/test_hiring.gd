extends TestCase
## T-0064: applying, interviews, starting tomorrow, quitting, registering, residents applying.


func _jobless_player(sim: Sim) -> Person:
	var player := sim.world.player()
	Hiring.quit(sim, player)
	sim.events.drain()
	return player


func _vacancy(sim: Sim) -> Dictionary:
	return Jobs.vacancies(sim)[0]


func test_applying_can_get_you_a_job_from_tomorrow() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _jobless_player(sim)
	player.needs["hygiene"] = 100.0
	var hired := false
	for day: int in 10:
		sim.clock.tick = SimClock.ticks_for(day, 12)
		var vacancy := _vacancy(sim)
		sim.submit(ApplyForJobCommand.new(player.id, vacancy["job_id"], vacancy["position"]))
		sim.step()
		if player.job != null:
			hired = true
			assert_eq(player.job.hired_day, day + 1, "starts tomorrow")
			assert_eq(Jobs.shift_on(sim, player, day), Vector2i(-1, -1), "no shift today")
			break
	assert_true(hired, "a clean, cheerful applicant gets a job within ten tries")


func test_one_application_a_day_and_taken_positions() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := _jobless_player(sim)
	sim.clock.tick = SimClock.ticks_for(1, 12)
	var vacancy := _vacancy(sim)
	Hiring.apply(sim, player, vacancy["job_id"], vacancy["position"])
	var second := Hiring.apply(sim, player, vacancy["job_id"], vacancy["position"])
	assert_false(second)
	var reasons: Array = sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"job_application").map(func(e: Dictionary) -> String: return e["data"]["reason"])
	assert_eq(reasons.back(), "already_applied" if player.job == null else "taken")
	sim.clock.tick = SimClock.ticks_for(2, 12)
	assert_false(Hiring.apply(sim, player, "bartender", 0), "someone works there")


func test_the_interview_favours_a_clean_cheerful_well_dressed_applicant() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var office := content().job("office_clerk")
	player.needs["hygiene"] = 100.0
	var clean := Hiring.chance(sim, player, office)
	var clean_mood := Mood.compute(player, content())
	player.needs["hygiene"] = 0.0
	var dirty := Hiring.chance(sim, player, office)
	var dirty_mood := Mood.compute(player, content())
	assert_true(clean - dirty > 0.4, "hygiene (and the mood it costs) counts a lot: %.2f vs %.2f" % [clean, dirty])
	assert_true(clean_mood >= dirty_mood)
	assert_true(clean <= 0.95 and dirty >= 0.05)


func test_quitting_pays_out_and_registering_brings_benefit() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.job.unpaid = 5000
	var bank := player.wallet.bank
	sim.submit(QuitJobCommand.new(player.id))
	sim.step()
	assert_true(player.job == null)
	assert_eq(player.wallet.bank, bank + 5000)
	assert_false(player.benefit_registered)
	sim.submit(RegisterUnemployedCommand.new(player.id))
	sim.step()
	assert_true(player.benefit_registered)
	sim.clock.tick = SimClock.ticks_for(7, 5, 59)
	sim.run_minutes(2)
	assert_true(player.wallet.statement.any(func(e: Dictionary) -> bool: return e["reason"] == "benefit"))


func test_residents_fill_vacancies_over_time() -> void:
	var sim := SimFactory.new_game(content(), 1)
	Jobs.holder(sim.world, "police_officer", 0).job = null  # this town has no jobless resident since T-0065
	var before := Jobs.vacancies(sim).size()
	sim.clock.tick = SimClock.ticks_for(7, 8, 59)
	for week: int in 3:
		sim.clock.tick = SimClock.ticks_for(7 * (week + 1), 8, 59)
		sim.run_minutes(2)
	assert_true(Jobs.vacancies(sim).size() < before or before == 0, "vacancies %d → %d" % [before, Jobs.vacancies(sim).size()])


