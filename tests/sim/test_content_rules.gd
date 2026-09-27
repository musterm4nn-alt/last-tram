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
