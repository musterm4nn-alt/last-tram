extends TestCase
## T-0091: the generated art trial fits the native grid and moves only with the person.


func test_shipped_set_covers_all_map_objects_and_visible_terrain() -> void:
	var art := ArtSet.load_set("imagegen", content())
	assert_eq(art.errors, [] as Array[String])
	for terrain: String in ["wall", "window", "door", "floor_wood", "floor_tile", "floor_stone", "sidewalk", "cobblestone", "road", "tram_track", "crossing", "grass", "hedge", "tree", "water", "bridge", "stairs", "fountain"]:
		var tile := art.terrain_tile(terrain, Vector2i(31, 28))
		assert_false(tile.is_empty(), terrain)
		assert_eq(tile["region"].size, Vector2i(16, 16))
	for id: String in ["fridge", "bed_double", "sofa", "tv", "stove", "shower", "sink", "kitchen_table", "desk", "bar_counter", "pub_table", "cafe_table", "cafe_counter", "bench", "spaeti_counter", "imbiss_counter", "atm", "tram_stop", "police_desk", "notice_case", "service_board", "vestry_chair", "wardrobe", "clothes_rack", "barber_chair", "washing_machine", "street_lamp"]:
		for rotation: int in 4:
			assert_false(art.object_sprite(id, rotation).is_empty(), "%s, rotation %d" % [id, rotation])


func test_fountain_uses_four_quadrants_of_one_cached_texture() -> void:
	var art := ArtSet.load_set("imagegen", content())
	var top_left := art.terrain_tile("fountain", Vector2i(31, 28))
	assert_eq(top_left["region"], Rect2i(0, 0, 16, 16))
	assert_eq(art.terrain_tile("fountain", Vector2i(32, 28))["region"], Rect2i(16, 0, 16, 16))
	assert_eq(art.terrain_tile("fountain", Vector2i(31, 29))["region"], Rect2i(0, 16, 16, 16))
	assert_eq(art.terrain_tile("fountain", Vector2i(32, 29))["region"], Rect2i(16, 16, 16, 16))
	assert_true(top_left["texture"] == art.terrain_tile("fountain", Vector2i(32, 29))["texture"])
	assert_eq(top_left["texture"].get_size(), Vector2(32, 32))
	assert_true(top_left["texture"].get_image().get_pixel(0, 0).a > 0.99, "cobblestone fills transparent fountain corners")


func test_high_resolution_objects_draw_at_logical_size_and_footprint_depth() -> void:
	var art := ArtSet.load_set("imagegen", content())
	var fridge := art.object_sprite("fridge", 0)
	assert_true(fridge["region"].size.y > 200, "the original generated PNG region is retained")
	assert_eq(fridge["size"].y, 28)
	var at := ObjectView2D.sprite_rect(Rect2(160, 160, 16, 16), fridge["size"])
	assert_eq(at.end.y, 176.0, "the sprite's feet sit on the footprint bottom")
	assert_true(at.size.x <= 16 and at.size.y <= 28)


func test_character_rows_and_all_four_walk_phases() -> void:
	var art := ArtSet.load_set("imagegen", content())
	var facings: Array[Vector2] = [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	for row: int in 4:
		for phase: int in 4:
			var sprite := art.characters.sprite(1, true, facings[row], true, phase * 0.125)
			assert_eq(sprite["character"], "player")
			assert_eq(sprite["frame"], row * 4 + phase)
			assert_eq(sprite["draw_rect"].position.y, -24.0, "the head baseline stays aligned")
		assert_eq(art.characters.sprite(1, true, facings[row], true, 0.5)["frame"], row * 4)
		assert_eq(art.characters.sprite(1, true, facings[row], false, 10.0)["frame"], row * 4 + 1)


func test_npc_designs_are_stable_and_cover_three_variants() -> void:
	var art := ArtSet.load_set("imagegen", content())
	var designs: Dictionary = {}
	for id: int in [3, 4, 5]:
		var a := art.characters.sprite(id, false, Vector2.DOWN, true, 0.0)
		var b := art.characters.sprite(id, false, Vector2.UP, true, 0.25)
		assert_eq(a["character"], b["character"])
		designs[a["character"]] = true
	assert_eq(designs.size(), 3)


func test_existing_sets_keep_appearance_based_people() -> void:
	assert_eq(ArtSet.new().characters.sprite(1, true, Vector2.DOWN, true, 1.0), {})
	var custom := ArtSet.load_set("custom", content())
	assert_eq(custom.errors, [] as Array[String])
	assert_eq(custom.characters.sprite(1, true, Vector2.DOWN, true, 1.0), {})


func test_walk_pose_stops_resets_and_freezes_while_paused() -> void:
	var pose := WalkPose2D.new()
	pose.advance(0.125, true, 1, false)
	assert_true(pose.walking)
	assert_eq(pose.elapsed, 0.125)
	pose.advance(10.0, false, 0, false)
	assert_eq(pose.elapsed, 0.125)
	assert_true(pose.walking, "pause preserves the current pose")
	pose.advance(0.125, false, 1, false)
	assert_false(pose.walking)
	assert_eq(pose.elapsed, 0.0)


func test_running_and_simulation_speed_advance_the_walk_cycle() -> void:
	var run := WalkPose2D.new()
	run.advance(0.125, true, 1, true)
	assert_eq(run.elapsed, 0.25)
	var fast := WalkPose2D.new()
	fast.advance(0.125, true, 3, false)
	assert_eq(fast.elapsed, 0.375)


func test_holding_direction_against_a_wall_does_not_walk_in_place() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#@#.#", "#####"])
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.RIGHT))
	sim.run_minutes(1)
	var person := sim.world.player()
	var pose := WalkPose2D.new()
	pose.advance(0.125, not person.pos.is_equal_approx(person.prev_pos), 1, person.running)
	assert_false(pose.walking)
	assert_true(person.move_intent != Vector2.ZERO, "input is still held; actual movement drives the pose")


func test_invalid_source_regions_and_patterns_fall_back_without_drawing() -> void:
	var texture := load("res://tests/fixtures/art2d/sheet.png") as Texture2D
	var sheets: Dictionary[String, Texture2D] = {"test": texture}
	for data: Dictionary in [{"sheet": "test", "source_rects": [[-1, 0, 16, 16]]}, {"sheet": "test", "source_rects": [[0, 0, 9999, 16]]}, {"sheet": "test", "source_rects": [[0, 0, 16, 16]], "pattern": [0, 2]}, {"sheet": "missing", "source_rects": [[0, 0, 16, 16]]}]:
		var reader := ContentReader.new()
		assert_eq(SourceTiles2D.read(data, sheets, reader, "fixture"), {})
		assert_false(reader.errors.is_empty())


func test_invalid_character_entries_leave_the_procedural_fallback_available() -> void:
	var reader := ContentReader.new()
	var parsed: Variant = reader.read_json("res://data/art2d/imagegen.json")
	var data: Dictionary = parsed
	var character: Dictionary = data["characters"]["player"]
	var texture := load(data["sheets"]["character_player"]) as Texture2D
	var sheets: Dictionary[String, Texture2D] = {"character_player": texture}
	for error_kind: String in ["fps", "frames", "rect", "size", "offset"]:
		var bad: Dictionary = character.duplicate(true)
		match error_kind:
			"fps": bad["fps"] = 0
			"frames": bad["frames"].remove_at(0)
			"rect": bad["frames"][0]["rect"] = [-1, 0, 12, 24]
			"size": bad["frames"][0]["size"] = [12, 0]
			"offset": bad["frames"][0]["offset"] = [999, 0]
		var errors := ContentReader.new()
		var sprites := CharacterSprites2D.new()
		sprites.read({"player": bad}, sheets, errors, "fixture")
		assert_false(errors.errors.is_empty(), error_kind)
		assert_eq(sprites.sprite(1, true, Vector2.DOWN, true, 0), {}, error_kind)
