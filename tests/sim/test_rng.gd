extends TestCase


func test_same_seed_same_numbers() -> void:
	var a := SimRng.new(99)
	var b := SimRng.new(99)
	for i: int in 5:
		assert_eq(a.stream("x").randi(), b.stream("x").randi())


func test_streams_are_independent() -> void:
	# Drawing from one stream must not change what another stream produces.
	var a := SimRng.new(1)
	var b := SimRng.new(1)
	for i: int in 10:
		a.stream("noise").randi()
	assert_eq(a.stream("autonomy").randi(), b.stream("autonomy").randi())


func test_different_seeds_differ() -> void:
	assert_ne(SimRng.new(1).stream("x").randi(), SimRng.new(2).stream("x").randi())


func test_state_roundtrip() -> void:
	var rng := SimRng.new(5)
	rng.stream("a").randi()
	var copy := SimRng.from_dict(JSON.parse_string(JSON.stringify(rng.to_dict())))
	assert_eq(copy.stream("a").randi(), rng.stream("a").randi())
	assert_eq(copy.master_seed, 5)
