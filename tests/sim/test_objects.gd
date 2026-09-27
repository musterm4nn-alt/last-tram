extends TestCase
## T-0001: world objects block movement, are placed from content and are saved.

const ROOM: PackedStringArray = [
	"################",
	"#..............#",
	"#...@..........#",
	"#..............#",
	"################",
]

const TINY: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]


func _place(sim: Sim, def_id: String, cell: Vector3i, rotation: int = 0) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = rotation
	return obj


func test_rotation_offsets_match_table() -> void:
	var size := Vector2i(2, 3)
	# (dx, dy) = (1, 2): rot0 (1, 2), rot1 (0, 1), rot2 (0, 0), rot3 (2, 0).
	assert_eq(ObjectDef.rotate_offset(Vector2i(1, 2), size, 0), Vector2i(1, 2))
	assert_eq(ObjectDef.rotate_offset(Vector2i(1, 2), size, 1), Vector2i(0, 1))
	assert_eq(ObjectDef.rotate_offset(Vector2i(1, 2), size, 2), Vector2i(0, 0))
	assert_eq(ObjectDef.rotate_offset(Vector2i(1, 2), size, 3), Vector2i(2, 0))
	# Ticket example: 1x1 fridge slot (0, 1) at rotation 1 is (-1, 0).
	assert_eq(ObjectDef.rotate_offset(Vector2i(0, 1), Vector2i(1, 1), 1), Vector2i(-1, 0))
	# Sofa 2x1 at rotation 1 stands upright.
	var sofa := content().object_def("sofa")
	assert_true(sofa != null)
	var foot := sofa.footprint(1)
	assert_eq(foot.size(), 2)
	assert_has(foot, Vector2i(0, 0))
	assert_has(foot, Vector2i(0, 1))


func test_rotation_facings_match_table() -> void:
	# Facing up (0, -1) turns clockwise: up -> right -> down -> left.
	assert_eq(ObjectDef.rotate_facing(Vector2i(0, -1), 0), Vector2i(0, -1))
	assert_eq(ObjectDef.rotate_facing(Vector2i(0, -1), 1), Vector2i(1, 0))
	assert_eq(ObjectDef.rotate_facing(Vector2i(0, -1), 2), Vector2i(0, 1))
	assert_eq(ObjectDef.rotate_facing(Vector2i(0, -1), 3), Vector2i(-1, 0))
	# Ticket example: fridge slot facing (0, -1) at rotation 1 faces (1, 0).
	assert_eq(ObjectDef.rotate_facing(Vector2i(0, -1), 1), Vector2i(1, 0))
	# Facing right (1, 0): rot1 (0, 1), rot2 (-1, 0), rot3 (0, -1).
	assert_eq(ObjectDef.rotate_facing(Vector2i(1, 0), 1), Vector2i(0, 1))
	assert_eq(ObjectDef.rotate_facing(Vector2i(1, 0), 2), Vector2i(-1, 0))
	assert_eq(ObjectDef.rotate_facing(Vector2i(1, 0), 3), Vector2i(0, -1))


func test_object_slots_match_data() -> void:
	var db := content()
	var fridge := db.object_def("fridge")
	assert_true(fridge != null)
	if fridge == null:
		return
	assert_eq(fridge.size, Vector2i(1, 1))
	assert_eq(fridge.use_slots.size(), 1)
	var sim := SimFactory.from_rows(db, TINY)
	var obj := _place(sim, "fridge", Vector3i(2, 1, 0), 0)
	assert_true(sim.world.add_object(obj))
	assert_eq(obj.slot_count(db), 1)
	assert_eq(obj.slot_cell(db, 0), Vector3i(2, 2, 0))
	assert_eq(obj.slot_facing(db, 0), Vector2i(0, -1))
	# Rotated once, the slot moves left of the fridge and faces right.
	var turned := _place(sim, "fridge", Vector3i(2, 1, 0), 1)
	assert_eq(turned.slot_cell(db, 0), Vector3i(1, 1, 0))
	assert_eq(turned.slot_facing(db, 0), Vector2i(1, 0))


func test_blocking_object_stops_movement_and_removal_frees_it() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var obj := _place(sim, "fridge", Vector3i(7, 2, 0), 0)
	assert_true(sim.world.add_object(obj))
	assert_false(sim.world.grid.is_walkable(Vector3i(7, 2, 0)))
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.RIGHT))
	sim.run_minutes(5)
	var player := sim.world.player()
	assert_true(player.pos.x + Person.RADIUS < 7.0, "box overlaps the fridge at %s" % player.pos)
	assert_true(player.pos.x + Person.RADIUS > 6.99, "stopped too early: %s" % player.pos)
	sim.world.remove_object(obj.id)
	assert_true(sim.world.grid.is_walkable(Vector3i(7, 2, 0)))
	assert_true(sim.world.objects_at(Vector3i(7, 2, 0)).is_empty())
	sim.run_minutes(5)
	assert_true(player.pos.x > 7.0, "should walk through after removal: %s" % player.pos)


func test_can_place_rejects_bad_placements_with_a_reason() -> void:
	var sim := SimFactory.from_rows(content(), TINY)
	var obj := _place(sim, "fridge", Vector3i(2, 1, 0), 0)
	assert_true(sim.world.add_object(obj))
	assert_eq(sim.world.can_place("fridge", Vector3i(2, 1, 0), 0), "overlaps object %d" % obj.id)
	assert_false(sim.world.add_object(_place(sim, "fridge", Vector3i(2, 1, 0), 0)))
	assert_eq(sim.world.can_place("fridge", Vector3i(0, 1, 0), 0), "blocked terrain")
	assert_eq(sim.world.can_place("fridge", Vector3i(10, 1, 0), 0), "outside the map")
	assert_eq(sim.world.can_place("ghost", Vector3i(2, 1, 0), 0), "unknown object")
	assert_true(sim.world.can_place("fridge", Vector3i(3, 1, 0), 0) == "")


func test_new_game_has_all_altstadt_objects() -> void:
	var db := content()
	var sim := SimFactory.new_game(db, 1)
	var expected: Array[ObjectPlacement] = db.districts["altstadt"].objects
	assert_true(expected.size() == 4, "altstadt should place 4 objects, has %d" % expected.size())
	assert_eq(sim.world.objects.size(), expected.size())
	var added := 0
	for event: Dictionary in sim.events.drain():
		if String(event["type"]) == "object_added":
			added += 1
	assert_eq(added, expected.size())
	# The player still starts on walkable ground, not inside an object.
	var player := sim.world.player()
	assert_true(player != null)
	assert_true(sim.world.grid.is_walkable(player.cell()))
	assert_true(sim.world.objects_at(player.cell()).is_empty())


func test_objects_survive_save_load() -> void:
	var sim := SimFactory.from_rows(content(), ROOM, 5)
	var obj := _place(sim, "fridge", Vector3i(7, 2, 0), 0)
	assert_true(sim.world.add_object(obj))
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.RIGHT))
	sim.run_steps(50)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	assert_eq(loaded.world.objects.size(), 1)
	assert_false(loaded.world.grid.is_walkable(Vector3i(7, 2, 0)))
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))


func test_save_and_continue_equals_uninterrupted_run_with_objects() -> void:
	var straight := SimFactory.from_rows(content(), ROOM, 9)
	assert_true(straight.world.add_object(_place(straight, "fridge", Vector3i(10, 2, 0), 0)))
	straight.submit(SetMoveIntentCommand.new(straight.world.player_id, Vector2.RIGHT))
	straight.run_steps(400)
	var first_half := SimFactory.from_rows(content(), ROOM, 9)
	assert_true(first_half.world.add_object(_place(first_half, "fridge", Vector3i(10, 2, 0), 0)))
	first_half.submit(SetMoveIntentCommand.new(first_half.world.player_id, Vector2.RIGHT))
	first_half.run_steps(173)
	var resumed := SaveCodec.from_json(SaveCodec.to_json(first_half), content())
	resumed.run_steps(227)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_save_with_unknown_def_id_skips_it_without_errors() -> void:
	var sim := SimFactory.from_rows(content(), TINY)
	assert_true(sim.world.add_object(_place(sim, "fridge", Vector3i(2, 1, 0), 0)))
	var data := SaveCodec.to_dict(sim)
	var world_data: Dictionary = data["world"]
	var objects_data: Array = world_data["objects"]
	objects_data.append({"id": 999, "def_id": "object_that_was_removed", "origin": [1, 1, 0], "rotation": 0})
	var errors: Array[String] = []
	var loaded := SaveCodec.from_dict(data, content(), errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	assert_true(errors.is_empty(), "unexpected errors: %s" % [errors])
	assert_eq(loaded.world.objects.size(), 1)
	assert_true(loaded.world.get_object(999) == null)
	loaded.run_minutes(1)
