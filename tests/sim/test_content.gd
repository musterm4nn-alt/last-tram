extends TestCase

const BROKEN_CONTENT: String = "res://tests/fixtures/content_broken"


func test_game_content_is_valid() -> void:
	var db := ContentDB.load_default()
	assert_true(db.is_valid(), "content errors:\n  " + "\n  ".join(db.errors))


func test_start_district_exists_with_ground_level() -> void:
	var db := content()
	assert_true(db.districts.has(db.start_district))
	var start: DistrictDef = db.districts[db.start_district]
	assert_true(start.levels.has(0), "start district needs a level 0")
	assert_true(start.size.x > 0 and start.size.y > 0)


func test_places_are_found_by_cell() -> void:
	var db := content()
	var spawn: Vector3i = db.districts[db.start_district].player_spawn
	var place := db.place_at(spawn)
	assert_true(place != null, "the player should start inside a named place")
	if place != null:
		assert_eq(place.kind, "home")


func test_new_game_player_starts_on_walkable_ground() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_true(player != null)
	assert_true(sim.world.grid.is_walkable(player.cell()))


func test_broken_content_is_reported_not_crashed() -> void:
	var db := ContentDB.new()
	db.load_from(BROKEN_CONTENT)
	var all := "\n".join(db.errors)
	assert_false(db.is_valid())
	assert_true(all.contains("duplicate terrain id"), all)
	assert_true(all.contains("unknown glyph"), all)
	assert_true(all.contains("expected"), "unequal row lengths must be reported: " + all)
	assert_true(all.contains("not walkable"), "spawn in a wall must be reported: " + all)
	assert_true(all.contains("player_start amounts must be >= 0"), all)
	assert_true(all.contains("'cash' must be [min, max] with min <= max"), all)
	for message: String in ["home 'wash_below' must be within 0..100", "pocket_money and cash_errand_score must be >= 0",
			"leave_margin must be >= 0, retry_minutes and look_ahead_hours >= 1", "lunch_after_minutes must be >= 1 and lunch_hunger within 0..100",
			"unknown relationship value 'love' in 'colleague_deltas'", "unknown need 'mana' in 'gentle_profile'"]:
		assert_true(all.contains(message), "T-0077 data rules: %s\n%s" % [message, all])


func test_moved_balance_numbers_load_from_data() -> void:
	var db := content()
	assert_eq(db.home_thresholds, {"wash_below": 45.0, "eat_below": 35.0, "low_below": 30.0} as Dictionary[String, float])
	assert_eq(db.economy.leave_margin, 10)
	assert_eq(db.economy.work_retry_minutes, 5)
	assert_eq(db.economy.look_ahead_hours, 3)
	assert_eq(db.economy.pocket_money, 1000)
	assert_near(db.economy.cash_errand_score, 4.0)
	assert_eq(db.economy.colleague_deltas, {"familiarity": 10.0, "friendship": 3.0} as Dictionary[String, float])
	assert_false(db.economy.gentle_profile.is_empty())


func test_the_shower_says_its_hygiene_once() -> void:
	var shower := content().interaction("take_shower")
	assert_eq(shower.advertise, shower.finish_needs, "without 'advertise', an interaction advertises what it gives")
	assert_near(float(shower.advertise.get("hygiene", 0.0)), 85.0)
	var text := FileAccess.get_file_as_string("res://data/interactions/home.json")
	var json := JSON.new()
	json.parse(text)
	for entry: Dictionary in json.data["interactions"]:
		if entry["id"] == "take_shower":
			assert_false(entry.has("advertise"), "the shower's hygiene is written once, in finish_needs")


func test_career_rules_are_checked_by_meaning() -> void:
	var expected := {
		"level_above_100": "performance 'promote_at' must be 0..100",
		"warning_order": "fire_at < warn_below < warning_clears_at <= promote_at",
		"fire_above_warning": "fire_at < warn_below < warning_clears_at <= promote_at",
		"clears_above_promotion": "fire_at < warn_below < warning_clears_at <= promote_at",
		"fractional_shifts": "'promote_after_shifts' must be a whole number >= 1",
		"zero_shifts": "'promote_after_shifts' must be a whole number >= 1",
	}
	for name: String in expected:
		var reader := ContentReader.new()
		var path := "res://tests/fixtures/economy_broken/%s.json" % name
		EconomyLoader.read_performance(reader, reader.read_json(path), path)
		var all := "\n".join(reader.errors)
		assert_true(all.contains(expected[name]), "%s: %s" % [name, all])
	var good := ContentReader.new()
	EconomyLoader.read_performance(good, good.read_json("res://data/economy.json"), "economy.json")
	assert_eq(good.errors, [] as Array[String], "the game's own rules are fine")


func test_broken_objects_are_reported_not_crashed() -> void:
	var db := ContentDB.new()
	db.load_from(BROKEN_CONTENT)
	var all := "\n".join(db.errors)
	assert_false(db.is_valid())
	assert_true(all.contains("duplicate object id"), all)
	assert_true(all.contains("at least one use slot"), "object with no slots must be reported: " + all)
	assert_true(all.contains("unit cardinal"), "bad facing must be reported: " + all)
	assert_true(all.contains("unknown object"), "placement with an unknown def must be reported: " + all)
	assert_true(all.contains("overlaps another object"), "overlapping placement must be reported: " + all)
	assert_true(all.contains("object 'crate' at (0, 0, 0) is on 'wall', which is not walkable"), "placement in a wall must be reported: " + all)
	assert_true(all.contains("rotation 5 must be 0..3"), "bad rotation must be reported: " + all)
	assert_true(all.contains("no usable use slot"), "placement with no usable slot must be reported: " + all)
	assert_true(all.contains("role 'boss' must be \"customer\" or \"staff\""), "an unknown slot role must be reported: " + all)


func test_game_objects_are_valid() -> void:
	var db := content()
	assert_true(db.object_def("fridge") != null)
	assert_true(db.object_def("bed_double") != null)
	assert_true(db.object_def("sofa") != null)
	assert_true(db.object_def("tv") != null)
	assert_true(db.object_def("ghost") == null)
	assert_false(db.districts["altstadt"].objects.is_empty())
