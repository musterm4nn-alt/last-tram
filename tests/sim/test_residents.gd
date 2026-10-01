extends TestCase
## T-0034: a new game fills the neighbour homes with generated households of adults.

const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"


func _residents(sim: Sim) -> Array[Person]:
	var out: Array[Person] = []
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id:
			out.append(person)
	return out


func test_seed_one_fills_every_neighbour_home() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var residents := _residents(sim)
	assert_true(residents.size() >= 20 and residents.size() <= 40, "%d residents" % residents.size())
	assert_eq(sim.world.households.size(), 16, "15 neighbour households and the player's")
	var homes: Dictionary[int, bool] = {}
	var cells: Dictionary[Vector3i, bool] = {}
	for household: Household in sim.world.households.values():
		assert_false(homes.has(household.home_lot_id), "one household per home")
		homes[household.home_lot_id] = true
		for member_id: int in household.member_ids:
			var person := sim.world.get_person(member_id)
			assert_eq(person.household_id, household.id)
			assert_eq(person.home_lot_id, household.home_lot_id)
	for person: Person in residents:
		var lot := Lots.lot_at(sim, person.cell())
		assert_true(lot != null and lot.id == person.home_lot_id, "%s starts at home" % person.full_name())
		assert_true(sim.world.grid.is_walkable(person.cell()))
		assert_false(cells.has(person.cell()), "two people on %s" % person.cell())
		cells[person.cell()] = true


func test_everyone_is_an_adult_with_a_valid_spec_over_twenty_seeds() -> void:
	for seed_value: int in range(1, 21):
		var sim := SimFactory.new_game(content(), seed_value)
		for person: Person in sim.world.people.values():
			assert_true(person.age_years >= Person.MIN_AGE, "seed %d: %s is %d" % [seed_value, person.full_name(), person.age_years])
			var spec := CharacterSpec.new()
			spec.first_name = person.first_name
			spec.last_name = person.last_name
			spec.gender = person.gender
			spec.pronouns = person.pronouns
			spec.age_years = person.age_years
			spec.appearance = person.appearance
			spec.outfit = person.outfit
			assert_eq(spec.validate(content()), PackedStringArray(), "seed %d: %s" % [seed_value, person.full_name()])


func test_the_same_seed_gives_the_same_town_and_another_seed_another() -> void:
	var a := SimFactory.new_game(content(), 4)
	var b := SimFactory.new_game(content(), 4)
	var c := SimFactory.new_game(content(), 5)
	assert_eq(SaveCodec.to_json(a), SaveCodec.to_json(b))
	assert_ne(Ser.to_json(a.world.to_dict()["people"]), Ser.to_json(c.world.to_dict()["people"]))


func test_couples_are_close_in_age_and_flatmates_are_two_or_three() -> void:
	var kinds: Dictionary[String, int] = {}
	for seed_value: int in range(1, 11):
		var sim := SimFactory.new_game(content(), seed_value)
		for household: Household in sim.world.households.values():
			if household.member_ids.has(sim.world.player_id):
				continue
			kinds[household.kind] = kinds.get(household.kind, 0) + 1
			match household.kind:
				Household.SINGLE:
					assert_eq(household.member_ids.size(), 1)
				Household.COUPLE:
					assert_eq(household.member_ids.size(), 2)
					var ages: Array[int] = []
					for id: int in household.member_ids:
						ages.append(sim.world.get_person(id).age_years)
					assert_true(absi(ages[0] - ages[1]) <= ResidentGenerator.COUPLE_AGE_GAP, "ages %s" % [ages])
				Household.FLATMATES:
					assert_true(household.member_ids.size() >= 2 and household.member_ids.size() <= 3)
	for kind: String in Household.KINDS:
		assert_true(kinds.get(kind, 0) > 0, "some %s households over ten towns" % kind)


func test_residents_may_enter_their_own_home_only() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var resident := _residents(sim)[0]
	var own := sim.world.lots[resident.home_lot_id]
	assert_true(Lots.may_enter(sim, resident, own))
	assert_false(Lots.may_enter(sim, resident, Lots.by_place(sim.world, SimFactory.PLAYER_HOME_PLACE)))
	for household: Household in sim.world.households.values():
		if household.home_lot_id != resident.home_lot_id:
			assert_false(Lots.may_enter(sim, resident, sim.world.lots[household.home_lot_id]))
	var player_household := sim.world.households[sim.world.player().household_id]
	assert_eq(player_household.member_ids, [sim.world.player_id] as Array[int])


func test_households_survive_saving_and_old_saves_have_none() -> void:
	var sim := SimFactory.new_game(content(), 2)
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	assert_eq(Ser.to_json(loaded.world.to_dict()["households"]), Ser.to_json(sim.world.to_dict()["households"]))
	var resident := _residents(sim)[0]
	assert_eq(loaded.world.get_person(resident.id).household_id, resident.household_id)
	var old := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	assert_true(old != null)
	assert_true(old.world.households.is_empty())


func test_a_household_member_list_naming_nobody_is_rejected() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	(data["world"]["households"][0] as Dictionary)["member_ids"] = [999999]
	assert_eq(SaveCodec.from_json(JSON.stringify(data), content()), null)


func test_free_will_waits_after_finding_nothing_to_do() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	var player := sim.world.player()
	player.last_input_tick = -AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	sim.run_minutes(1)
	assert_true(player.autonomy_retry_tick > sim.clock.tick, "nothing here: look again later")
	assert_true(player.autonomy_retry_tick <= sim.clock.tick + AutonomySystem.RETRY_MINUTES * SimClock.STEPS_PER_GAME_MINUTE)
