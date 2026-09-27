extends TestCase
## T-0018: there are no children in the game. Every person is 18 or older, whether
## created for a new game or generated at random.


func test_every_person_in_a_new_game_is_an_adult() -> void:
	var sim := SimFactory.new_game(content(), 1)
	assert_false(sim.world.people.is_empty(), "a new game has no people")
	for person: Person in sim.world.people.values():
		assert_true(person.age_years >= 18, "%s is %d, not an adult" % [person.full_name(), person.age_years])


func test_random_characters_are_all_adults() -> void:
	for seed_value: int in range(1, 201):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var spec := CharacterSpec.random(content(), rng)
		assert_true(spec.age_years >= 18, "seed %d gave age %d" % [seed_value, spec.age_years])


func test_ages_stay_adult_even_if_content_is_wrong() -> void:
	var db := ContentDB.load_default()  # a private copy: the shared test content must not change
	db.appearance.age_min = 12
	db.appearance.age_max = 17
	for seed_value: int in range(1, 51):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var spec := CharacterSpec.random(db, rng)
		assert_true(spec.age_years >= 18, "seed %d gave age %d" % [seed_value, spec.age_years])
	var young := CharacterSpec.default_player(db)
	young.age_years = 16
	assert_false(young.validate(db).is_empty(), "age 16 must be rejected even when the content allows it")


func test_a_person_is_never_younger_than_18() -> void:
	var person := Person.new()
	person.age_years = 12
	assert_eq(person.age_years, 18)
	var saved := Person.new().to_dict()
	saved["age_years"] = 15
	assert_eq(Person.from_dict(saved).age_years, 18, "a save must not make anyone younger than 18")
