extends TestCase
## T-0075: backgrounds set the player's start: money, job, skills, people they know, a feeling.


func _start(background: String) -> Sim:
	var spec := CharacterSpec.default_player(content())
	spec.background = background
	return SimFactory.new_game(content(), 1, spec)


func test_backgrounds_load() -> void:
	var ids: Array = content().backgrounds.keys()
	ids.sort()
	assert_eq(ids, ["burnout", "ex_con", "local", "newcomer", "student"])
	assert_eq(content().default_background, "newcomer")


func test_each_background_gives_exactly_its_data() -> void:
	for id: String in content().backgrounds:
		var def := content().background(id)
		var sim := _start(id)
		var player := sim.world.player()
		assert_eq(player.origin, id)
		assert_eq(player.record, def.record, id)
		assert_eq(player.wallet.cash, def.cash, id + " cash")
		assert_eq(player.wallet.bank, def.bank, id + " bank")
		if def.job_id.is_empty():
			assert_eq(player.job, null, id + ": no job")
		else:
			assert_eq(player.job.job_id, def.job_id, id)
		for skill_id: String in def.skills:
			assert_eq(Skills.level(content(), player, skill_id), int(def.skills[skill_id]), "%s %s" % [id, skill_id])
		if not def.moodlet_id.is_empty():
			assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == def.moodlet_id), id + " feels it")
		var known := 0
		for r: Relationship in player.relationships.values():
			var other := sim.world.get_person(r.other_id)
			if other != null and other.household_id != player.household_id and r.familiarity >= 30.0:
				known += 1
				assert_true(Social.relationship(other, player.id).familiarity >= 30.0, "both ways")
		assert_eq(known, def.knows, id + " knows")
		assert_eq(Money.held(sim.world), sim.world.ledger.balance(), id + ": the ledger balances")


func test_no_choice_is_the_default_and_unknown_is_refused() -> void:
	var sim := SimFactory.new_game(content(), 1)
	assert_eq(sim.world.player().origin, "newcomer")
	var spec := CharacterSpec.default_player(content())
	spec.first_name = "Mira"
	spec.last_name = "Kovač"
	spec.background = "astronaut"
	assert_has(spec.validate(content()), "unknown background 'astronaut'")
	spec.background = "student"
	assert_eq(CharacterSpec.from_dict(spec.to_dict()).background, "student", "the spec keeps it")


func test_the_record_and_origin_are_saved() -> void:
	var sim := _start("ex_con")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	assert_true(loaded.world.player().record)
	assert_eq(loaded.world.player().origin, "ex_con")
	var old := SaveMigrations.migrate({"save_version": 18, "world": {"player_id": 4, "people": [{"id": 4}, {"id": 5}]}})
	assert_eq(old["world"]["people"][0]["origin"], "newcomer")
	assert_eq(old["world"]["people"][1]["origin"], "")
