extends TestCase
## T-0033: seven personality axes on every person, saved, random for generated people.

const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"
## CharacterSpec.random(seed) before personality existed (everything but the personality).
const GOLDEN: Dictionary = {
	1234: '{"age":29,"appearance":{"build":"stocky","eye_colour":"hazel","facial_hair":"none","features":[],"hair_colour":"red","hair_style":"afro","height_cm":185,"skin_tone":"skin_07"},"first":"Lea","gender":"woman","last":"Procházka","outfit":{"bag":{"colour":"burgundy","item":"tote_bag"},"bottom":{"colour":"pink","item":"skirt"},"feet":{"colour":"brown","item":"boots"},"head":{"colour":"olive","item":"cap"},"top":{"colour":"burgundy","item":"sweater"}},"pronouns":"she"}',
	7: '{"age":66,"appearance":{"build":"slim","eye_colour":"blue","facial_hair":"stubble","features":[],"hair_colour":"white","hair_style":"bald","height_cm":185,"skin_tone":"skin_08"},"first":"Sven","gender":"nonbinary","last":"de Vries","outfit":{"bottom":{"colour":"red","item":"track_pants"},"feet":{"colour":"red","item":"trainers"},"neck":{"colour":"grey","item":"scarf"},"top":{"colour":"red","item":"t_shirt"}},"pronouns":"they"}',
}


func test_random_personalities_stay_in_range_and_cluster_near_zero() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var moderate := 0
	var total := 0
	for i: int in 1000:
		var personality := Personality.random(rng)
		for axis: String in Personality.AXES:
			var value := personality.get_axis(axis)
			assert_true(value >= -100 and value <= 100, "%s = %d" % [axis, value])
			total += 1
			if absi(value) <= 50:
				moderate += 1
	assert_true(moderate > total * 0.65, "most values are moderate: %d of %d" % [moderate, total])
	assert_true(moderate < total * 0.85, "but not all: %d of %d" % [moderate, total])


func test_the_same_seed_gives_the_same_personality() -> void:
	var a := RandomNumberGenerator.new()
	a.seed = 7
	var b := RandomNumberGenerator.new()
	b.seed = 7
	assert_eq(Personality.random(a).to_dict(), Personality.random(b).to_dict())


func test_values_are_clamped_and_unknown_axes_ignored() -> void:
	var personality := Personality.new()
	personality.set_axis("temper", 250)
	personality.set_axis("kindness", -400)
	personality.set_axis("charm", 30)
	assert_eq(personality.get_axis("temper"), 100)
	assert_eq(personality.get_axis("kindness"), -100)
	assert_eq(personality.get_axis("charm"), 0)
	assert_false(personality.values.has("charm"))
	var loaded := Personality.from_dict({"bravery": 999, "charm": 5})
	assert_eq(loaded.get_axis("bravery"), 100)
	assert_eq(loaded.get_axis("honesty"), 0, "missing axes are neutral")


func test_random_spec_keeps_every_earlier_draw() -> void:
	# Recorded on main before T-0033: personality is drawn last, so these stay the same.
	for seed_value: int in GOLDEN:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var spec := CharacterSpec.random(content(), rng)
		var got := JSON.stringify({"first": spec.first_name, "last": spec.last_name, "age": spec.age_years,
			"gender": spec.gender, "pronouns": spec.pronouns, "appearance": spec.appearance.to_dict(),
			"outfit": spec.outfit.to_dict()})
		assert_eq(got, GOLDEN[seed_value], "seed %d" % seed_value)


func test_default_player_is_neutral() -> void:
	var spec := CharacterSpec.default_player(content())
	for axis: String in Personality.AXES:
		assert_eq(spec.personality.get_axis(axis), 0)


func test_person_and_spec_round_trip_the_personality() -> void:
	var spec := CharacterSpec.default_player(content())
	spec.personality.set_axis("ambition", 61)
	spec.personality.set_axis("vice", -17)
	var spec_back := CharacterSpec.from_dict(JSON.parse_string(JSON.stringify(spec.to_dict())))
	assert_eq(spec_back.personality.get_axis("ambition"), 61)
	assert_eq(spec_back.personality.get_axis("vice"), -17)
	var sim := SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	spec.apply_to(sim.world.player())
	spec.personality.set_axis("ambition", 0)
	assert_eq(sim.world.player().personality.get_axis("ambition"), 61, "apply_to copies")
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	assert_eq(loaded.world.player().personality.get_axis("ambition"), 61)
	assert_eq(loaded.world.player().personality.get_axis("vice"), -17)


func test_an_old_save_loads_with_neutral_personalities() -> void:
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	assert_true(sim != null)
	for person: Person in sim.world.people.values():
		for axis: String in Personality.AXES:
			assert_eq(person.personality.get_axis(axis), 0)


func test_an_out_of_range_personality_in_a_save_is_rejected() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	for person: Variant in data["world"]["people"]:
		(person as Dictionary)["personality"] = {"temper": 400}
	assert_eq(SaveCodec.from_json(JSON.stringify(data), content()), null)
