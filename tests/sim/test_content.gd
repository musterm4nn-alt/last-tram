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
	assert_true(all.contains("not walkable"), "placement in a wall must be reported: " + all)
	assert_true(all.contains("rotation"), "bad rotation must be reported: " + all)
	assert_true(all.contains("no usable use slot"), "placement with no usable slot must be reported: " + all)


func test_game_objects_are_valid() -> void:
	var db := content()
	assert_true(db.object_def("fridge") != null)
	assert_true(db.object_def("bed_double") != null)
	assert_true(db.object_def("sofa") != null)
	assert_true(db.object_def("tv") != null)
	assert_true(db.object_def("ghost") == null)
	assert_false(db.districts["altstadt"].objects.is_empty())
