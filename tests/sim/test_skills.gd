extends TestCase
## T-0071: skills grow with practice, and pay off in meals, conversations, work and interviews.


func _game() -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.world.player().free_will = false
	sim.events.drain()
	return sim


func _xp(levels: int) -> float:
	return levels * content().skill_rules.xp_per_level


func test_skill_content_loads() -> void:
	assert_eq(content().skills.keys().size(), 5)
	assert_eq(content().skill_rules.max_level, 10)
	assert_eq(content().interaction("cook_meal").skill_xp, {"cooking": 60.0} as Dictionary[String, float])
	assert_eq(content().interaction("cook_meal").finish_skill, "cooking")
	assert_eq(content().job("office_clerk").skill, "logic")
	assert_eq(content().job("office_clerk").levels[1].requires, {"logic": 2.0} as Dictionary[String, float])
	for job: JobDef in content().jobs.values():
		assert_true(content().skill(job.skill) != null, job.id + " trains a skill")


func test_levels_from_xp_and_level_up_events() -> void:
	var sim := _game()
	var player := sim.world.player()
	assert_eq(Skills.level(content(), player, "cooking"), 0)
	Skills.gain(sim, player, "cooking", _xp(1) - 1.0)
	assert_eq(Skills.level(content(), player, "cooking"), 0)
	assert_eq(sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"skill_up").size(), 0)
	Skills.gain(sim, player, "cooking", 1.0)
	assert_eq(Skills.level(content(), player, "cooking"), 1)
	var ups := sim.events.drain().filter(func(e: Dictionary) -> bool: return e["type"] == &"skill_up")
	assert_eq(ups.size(), 1)
	assert_eq(ups[0]["data"], {"person_id": player.id, "skill_id": "cooking", "level": 1})
	Skills.gain(sim, player, "cooking", _xp(50))
	assert_eq(Skills.level(content(), player, "cooking"), 10, "capped at max_level")
	Skills.gain(sim, player, "no_such_skill", 100.0)
	assert_false(player.skills.has("no_such_skill"))
	assert_eq(Skills.text(content(), player), "Cooking 10")


func test_cooking_practice_and_better_meals() -> void:
	var sim := _game()
	var player := sim.world.player()
	var stove: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "stove" and lot != null and lot.id == player.home_lot_id:
			stove = obj
	var cell := stove.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	player.needs["hunger"] = 10.0
	sim.submit(QueueInteractionCommand.new(player.id, "cook_meal", stove.id))
	sim.run_minutes(31)
	assert_near(float(player.skills.get("cooking", 0.0)), 30.0, 0.01, "half an hour at 60 XP per hour")
	assert_near(Skills.finish_factor(content(), player, content().interaction("cook_meal")), 1.0, 0.0001)
	player.skills["cooking"] = _xp(4)
	assert_near(Skills.finish_factor(content(), player, content().interaction("cook_meal")), 1.2, 0.0001, "level 4: meals fill 20% more")
	var hunger_before := 10.0
	player.needs["hunger"] = hunger_before
	sim.submit(QueueInteractionCommand.new(player.id, "cook_meal", stove.id))
	sim.run_minutes(31)
	var decay := content().need("hunger").decay_per_hour * 0.5
	assert_near(float(player.needs["hunger"]), hunger_before + 60.0 * 1.2 - decay, 0.5)


func test_work_trains_the_jobs_skill_and_helps_performance() -> void:
	var sim := _game()
	var player := sim.world.player()
	sim.clock.tick = SimClock.ticks_for(0, 8, 55)
	var shelter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "tram_stop":
			shelter = obj
	var cell := shelter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, "work", shelter.id))
	sim.run_minutes(8 * 60 + 10)
	assert_near(float(player.skills.get("logic", 0.0)), 8.0 * content().skill_rules.work_xp_per_hour, 0.5, "a day at the office trains logic")
	var performance := player.job.performance
	player.skills["logic"] = _xp(5)
	player.job.shift_start = SimClock.ticks_for(1, 9)
	player.job.shift_minutes = 480
	player.job.shift_late = 0
	var rules := content().economy.performance
	Careers.settle(sim, player)
	var gained := player.job.performance - performance
	var mood_bonus := float(rules["good_mood"]) if Mood.compute(player, content()) > 0.0 else 0.0
	assert_near(gained, float(rules["shift_done"]) + mood_bonus + 5 * content().skill_rules.performance_per_level, 0.0001)


func test_promotion_needs_the_skill() -> void:
	var sim := _game()
	var player := sim.world.player()
	var rules := content().economy.performance
	player.job.performance = float(rules["promote_at"]) + 5.0
	player.job.level_shifts = int(rules["promote_after_shifts"]) + 1
	player.job.shift_start = SimClock.ticks_for(1, 9)
	player.job.shift_minutes = 480
	Careers.settle(sim, player)
	assert_eq(player.job.level, 0, "no logic: no promotion to Senior clerk")
	player.skills["logic"] = _xp(2)
	player.job.shift_start = SimClock.ticks_for(2, 9)
	player.job.shift_minutes = 480
	Careers.settle(sim, player)
	assert_eq(player.job.level, 1, "logic 2: promoted")


func test_charisma_helps_conversations_and_interviews() -> void:
	var sim := _game()
	var player := sim.world.player()
	var other: Person = null
	for person: Person in sim.world.people.values():
		if person.id != player.id:
			other = person
			break
	var chat := content().interaction("chat")
	var insult := content().interaction("insult")
	var plain := Conversations.acceptance(sim, player, other, chat)
	var plain_insult := Conversations.acceptance(sim, player, other, insult)
	player.skills["charisma"] = _xp(5)
	var charming := Conversations.acceptance(sim, player, other, chat)
	var logit := func(p: float) -> float: return log(p / (1.0 - p))
	assert_near(logit.call(charming) - logit.call(plain), 5 * content().skill_rules.charisma_per_level, 0.0001)
	assert_near(Conversations.acceptance(sim, player, other, insult), plain_insult, 0.0001, "charm doesn't make insults land")
	var job := content().job("bartender")
	player.skills.erase("charisma")
	var before := Hiring.chance(sim, player, job)
	player.skills["charisma"] = _xp(3)
	assert_near(Hiring.chance(sim, player, job) - before, 3 * content().skill_rules.interview_per_level, 0.0001)


func test_skills_survive_saves() -> void:
	var sim := _game()
	var player := sim.world.player()
	Skills.gain(sim, player, "logic", 123.25)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	assert_eq(loaded.world.player().skills, {"logic": 123.25} as Dictionary[String, float])
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	assert_eq(SaveMigrations.migrate({"save_version": 14, "world": {"people": [{"id": 1}]}})["world"]["people"][0]["skills"], {})
