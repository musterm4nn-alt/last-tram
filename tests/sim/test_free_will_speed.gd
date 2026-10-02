extends TestCase
## T-0078: free will's shortcuts change nothing: the pruned decision equals scoring every
## option, the walk length equals the full path's, and noise doesn't depend on other options.


func test_decide_equals_choose_over_all_candidates() -> void:
	var sim := SimFactory.new_game(content(), 2)
	var checked := 0
	var picked := 0
	for hour: int in [2, 9, 13, 19, 22]:
		sim.run_minutes(60 * 3)
		for person: Person in sim.world.people.values():
			var a := RandomNumberGenerator.new()
			var b := RandomNumberGenerator.new()
			a.seed = person.id * 7919 + hour
			b.seed = a.seed
			var full := Autonomy.choose(Autonomy.candidates(sim, person), a)
			var fast := Autonomy.decide(sim, person, b)
			assert_eq(fast.to_dict() if fast != null else {}, full.to_dict() if full != null else {}, "%s at %d" % [person.full_name(), sim.clock.tick])
			assert_eq(a.state, b.state, "the same draws")
			checked += 1
			picked += 0 if full == null else 1
	assert_true(checked > 100 and picked > 10, "a real sample (%d checks, %d picks)" % [checked, picked])


func test_path_length_matches_find_path() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cells: Array[Vector3i] = []
	for person: Person in sim.world.people.values():
		cells.append(person.cell())
	for i: int in 200:
		var from: Vector3i = cells[rng.randi_range(0, cells.size() - 1)]
		var to: Vector3i = cells[rng.randi_range(0, cells.size() - 1)]
		var path := sim.nav.find_path(from, to)
		assert_eq(sim.nav.path_length(from, to), path.size() if not path.is_empty() else -1, "%s -> %s" % [from, to])


func test_noise_ignores_other_options() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var salt := rng.randi()
	var first := Autonomy.noise(salt, 40, "cook_meal")
	assert_eq(Autonomy.noise(salt, 40, "cook_meal"), first, "the same option, the same noise")
	assert_true(first >= 0.0 and first < Autonomy.NOISE)
	assert_ne(Autonomy.noise(salt, 41, "cook_meal"), first)
	var few: Array[AutonomyOption] = [AutonomyOption.new(40, "cook_meal", 10.0, 0)]
	var more: Array[AutonomyOption] = [AutonomyOption.new(40, "cook_meal", 10.0, 0), AutonomyOption.new(999, "sit", -2.0, 50)]  # too far to be worth it
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 3
	b.seed = 3
	assert_eq(Autonomy.choose(few, a).interaction_id, Autonomy.choose(more, b).interaction_id, "a far bench doesn't reshuffle the pick")
