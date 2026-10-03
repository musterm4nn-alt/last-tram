extends TestCase
## T-0058: jobs, positions, residents with jobs, and fitting routines.

const BROKEN: String = "res://tests/fixtures/jobs_broken.json"


func test_jobs_load() -> void:
	var clerk := content().job("office_clerk")
	assert_true(clerk != null)
	if clerk == null:
		return
	assert_eq(clerk.session, JobDef.RABBIT_HOLE)
	assert_eq(clerk.positions.size(), 3, "count expands")
	assert_eq(clerk.levels[0].wage, 1400)
	assert_eq(content().job("bartender").positions[0].hours(), 9, "17–2 is nine hours")
	assert_eq(content().background(content().default_background).job_id, "office_clerk", "the default background's job")
	assert_eq(content().economy.retirement_age, 67)


func test_broken_jobs_are_reported() -> void:
	var db := ContentDB.load_default()
	var reader := ContentReader.new()
	JobLoader.load(db, reader, BROKEN)
	var all := "\n".join(reader.errors)
	for expected: String in ["'bad_place': unknown place 'nowhere'", "'no_workplace': no object tagged 'tram_stop' stands on 'church_st_nikolai'",
			"'zero_wage': level 'T' needs a wage > 0", "'bad_day': unknown day 'funday'", "'same_hours': a position needs two different whole hours",
			"'bad_session': 'session' must be one of"]:
		assert_true(all.contains(expected), "missing: %s\n%s" % [expected, all])


func test_new_towns_fill_positions_sensibly() -> void:
	for seed_value: int in [1, 2, 3]:
		var sim := SimFactory.new_game(content(), seed_value)
		var player := sim.world.player()
		assert_eq(player.job.job_id, "office_clerk", "the player starts as an office clerk")
		for job: JobDef in content().jobs.values():
			for position: int in job.positions.size():
				var holder := Jobs.holder(sim.world, job.id, position)
				if job.start_filled >= 1.0:
					assert_true(holder != null, "%s %d is always filled (seed %d)" % [job.id, position, seed_value])
				if holder != null and holder.id != player.id:
					assert_true(Jobs.fits_routine(content(), job, position, holder.routine_id),
						"%s's routine fits %s (seed %d)" % [holder.full_name(), job.id, seed_value])
					var best := 0
					for routine_id: String in content().routines:
						best = maxi(best, Jobs.routine_fit(content(), job, position, routine_id))
					assert_eq(Jobs.routine_fit(content(), job, position, holder.routine_id), best,
						"%s's routine leaves them the most evening out a %s can have (seed %d)" % [holder.full_name(), job.id, seed_value])
		var working_age := 0
		var employed := 0
		for person: Person in sim.world.people.values():
			if person.age_years >= content().economy.retirement_age:
				assert_true(person.job == null, "retired people don't work")
			elif person.id != player.id:
				working_age += 1
				employed += 1 if person.job != null else 0
		assert_true(employed >= working_age / 2, "most working-age residents have jobs (seed %d: %d of %d)" % [seed_value, employed, working_age])
		var taken: Dictionary = {}
		for person: Person in sim.world.people.values():
			if person.job != null:
				var key := "%s/%d" % [person.job.job_id, person.job.position]
				assert_false(taken.has(key), "one person per position")
				taken[key] = true


func test_routines_that_leave_an_evening_out_suit_a_late_shift_better() -> void:
	var police := content().job("police_officer")
	var late := 1  # 14–22
	assert_eq(police.positions[late].from, 14)
	assert_eq(Jobs.routine_fit(content(), police, late, "early_bird"), 1, "fits, but 17–21 out is all at work")
	assert_true(Jobs.routine_fit(content(), police, late, "night_owl") > Jobs.routine_fit(content(), police, late, "regular"),
		"a night owl still gets 22–02 out; a regular only 22–23")
	assert_eq(Jobs.routine_fit(content(), content().job("bartender"), 0, "early_bird"), 0, "doesn't fit at all")


func test_same_seed_same_jobs() -> void:
	var a := SimFactory.new_game(content(), 4)
	var b := SimFactory.new_game(content(), 4)
	for id: int in a.world.people:
		var ja := a.world.people[id].job
		var jb := b.world.people[id].job
		assert_eq(ja.to_dict() if ja != null else {}, jb.to_dict() if jb != null else {})
		assert_eq(a.world.people[id].routine_id, b.world.people[id].routine_id)


func test_shift_times() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_eq(Jobs.shift_on(sim, player, 0), Vector2i(SimClock.ticks_for(0, 9), SimClock.ticks_for(0, 17)))
	assert_eq(Jobs.shift_on(sim, player, 5), Vector2i(-1, -1), "Saturday off")
	var bartender := Jobs.holder(sim.world, "bartender", 0)
	assert_eq(Jobs.shift_on(sim, bartender, 2), Vector2i(SimClock.ticks_for(2, 17), SimClock.ticks_for(3, 2)), "ends after midnight")
	player.job = null
	assert_eq(Jobs.shift_on(sim, player, 0), Vector2i(-1, -1))


func test_routines_and_days_in_words() -> void:
	var clerk := content().job("office_clerk")
	var bartender := content().job("bartender")
	assert_true(Jobs.fits_routine(content(), clerk, 0, "regular"))
	assert_false(Jobs.fits_routine(content(), clerk, 0, "night_owl"), "night owls sleep until 10")
	assert_true(Jobs.fits_routine(content(), bartender, 0, "night_owl"))
	assert_false(Jobs.fits_routine(content(), bartender, 0, "early_bird"))
	assert_eq(Jobs.days_text(clerk.positions[0]), "Mon–Fri")
	assert_eq(Jobs.days_text(bartender.positions[0]), "Mon–Thu")
	assert_eq(Jobs.days_text(bartender.positions[1]), "Fri–Sun")
	var daily := ShiftDef.new()
	daily.days = PackedInt32Array([0, 1, 2, 3, 4, 5, 6])
	assert_eq(Jobs.days_text(daily), "daily")
	var odd := ShiftDef.new()
	odd.days = PackedInt32Array([0, 2])
	assert_eq(Jobs.days_text(odd), "Mon, Wed")


func test_hiring_checks_the_position() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var person := sim.world.player()
	person.job = null
	var taken := Jobs.holder(sim.world, "bartender", 0)
	assert_true(taken != null)
	assert_false(Jobs.hire(sim, person, "bartender", 0), "taken")
	assert_false(Jobs.hire(sim, person, "bartender", 7), "no such position")
	assert_false(Jobs.hire(sim, person, "astronaut", 0), "no such job")
	var open := Jobs.vacancies(sim)[0]
	assert_true(Jobs.hire(sim, person, open["job_id"], open["position"]))
	assert_eq(person.job.job_id, open["job_id"])


func test_jobs_survive_saving_and_old_saves_have_none() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		for id: int in sim.world.people:
			var before := sim.world.people[id].job
			var after := loaded.world.people[id].job
			assert_eq(after.to_dict() if after != null else {}, before.to_dict() if before != null else {})
	var data := SaveCodec.to_dict(sim)
	data["world"]["people"][0]["job"] = {"job_id": "astronaut", "position": 0, "level": 0, "performance": 50.0, "hired_day": 0}
	var dropped := SaveCodec.from_dict(data, content(), errors)
	assert_true(dropped != null and dropped.world.people.values()[0].job == null, "an unknown job is dropped")
	var old := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v5_basic.json"), content(), errors)
	assert_true(old != null, "%s" % [errors])
	if old != null:
		for person: Person in old.world.people.values():
			assert_true(person.job == null)
