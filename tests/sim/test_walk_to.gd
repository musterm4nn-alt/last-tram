extends TestCase
## T-0004: people follow paths via WalkToCommand; direct input overrides the path.

const OPEN_ROOM: PackedStringArray = [
	"########",
	"#@.....#",
	"#......#",
	"#......#",
	"########",
]

const CORRIDOR: PackedStringArray = [
	"########",
	"#@.....#",
	"########",
]

const DETOUR: PackedStringArray = [
	"#####",
	"#@#.#",
	"#...#",
	"#...#",
	"#####",
]

const SEALED: PackedStringArray = [
	"#####",
	"#@#.#",
	"#####",
]


func _place(sim: Sim, def_id: String, cell: Vector3i, rotation: int = 0) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = rotation
	return obj


func _centre(cell: Vector3i) -> Vector2:
	return Vector2(cell.x + 0.5, cell.y + 0.5)


func _walk_to(sim: Sim, target: Vector3i) -> void:
	sim.submit(WalkToCommand.new(sim.world.player_id, target))


func _events_of(sim: Sim, type: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == type:
			out.append(event)
	return out


func test_walk_to_open_room_arrives_with_empty_path() -> void:
	var sim := SimFactory.from_rows(content(), OPEN_ROOM)
	var target := Vector3i(5, 3, 0)
	_walk_to(sim, target)
	sim.run_steps(500)
	var player := sim.world.player()
	assert_true(player.path.is_empty(), "path should be empty, has %s" % [player.path])
	assert_vec_near(player.pos, _centre(target), 0.0001)


func test_walk_to_around_wall_arrives_without_overlapping_blocked_cells() -> void:
	var sim := SimFactory.from_rows(content(), DETOUR)
	var target := Vector3i(3, 1, 0)
	_walk_to(sim, target)
	var player := sim.world.player()
	for i: int in 500:
		sim.step()
		if MovementSystem.is_box_blocked(sim.world.grid, player.level, player.pos):
			fail("overlapping a blocked cell at step %d, pos %s" % [i, player.pos])
			return
		if player.path.is_empty():
			break
	assert_true(player.path.is_empty(), "never arrived at %s" % target)
	assert_vec_near(player.pos, _centre(target), 0.0001)


func test_straight_walk_takes_ceil_steps_with_carry_over() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	var player := sim.world.player()
	var target := Vector3i(6, 1, 0)
	var cells := 5
	var expected := ceili(float(cells) / (player.walk_speed / float(SimClock.STEPS_PER_GAME_MINUTE)))
	assert_eq(expected, 23)
	_walk_to(sim, target)
	sim.run_steps(expected - 1)
	assert_false(player.path.is_empty(), "arrived a step early")
	assert_true(player.pos.distance_to(_centre(target)) > 0.0001, "arrived a step early")
	sim.run_steps(1)
	assert_true(player.path.is_empty(), "not arrived after %d steps" % expected)
	assert_vec_near(player.pos, _centre(target), 0.0001)


func test_unreachable_target_fails_and_keeps_earlier_path() -> void:
	var sim := SimFactory.from_rows(content(), SEALED)
	var player := sim.world.player()
	var start := player.pos
	var target := Vector3i(3, 1, 0)
	_walk_to(sim, target)
	sim.run_steps(1)
	var failed := _events_of(sim, &"path_failed")
	assert_eq(failed.size(), 1)
	assert_eq(failed[0]["data"]["person_id"], player.id)
	assert_eq(Ser.to_cell(failed[0]["data"]["target"]), target)
	assert_vec_near(player.pos, start)
	assert_true(player.path.is_empty())
	# An earlier path keeps going after a failed command.
	var sim2 := SimFactory.from_rows(content(), OPEN_ROOM)
	var player2 := sim2.world.player()
	var good := Vector3i(5, 3, 0)
	_walk_to(sim2, good)
	sim2.run_steps(1)
	assert_false(player2.path.is_empty())
	sim2.events.drain()
	_walk_to(sim2, Vector3i(0, 0, 0))
	sim2.run_steps(1)
	var failed2 := _events_of(sim2, &"path_failed")
	assert_eq(failed2.size(), 1)
	assert_false(player2.path.is_empty(), "earlier path should be kept")


func test_walk_to_own_cell_stops_without_event() -> void:
	var sim := SimFactory.from_rows(content(), OPEN_ROOM)
	var player := sim.world.player()
	_walk_to(sim, Vector3i(5, 3, 0))
	sim.run_steps(1)
	assert_false(player.path.is_empty())
	sim.events.drain()
	_walk_to(sim, player.cell())
	sim.run_steps(1)
	assert_true(player.path.is_empty())
	assert_eq(player.move_intent, Vector2.ZERO)
	assert_true(sim.events.drain().is_empty(), "stopping should emit no event")


func test_nonzero_intent_clears_path_but_zero_leaves_it() -> void:
	var sim := SimFactory.from_rows(content(), OPEN_ROOM)
	var player := sim.world.player()
	_walk_to(sim, Vector3i(5, 3, 0))
	sim.run_steps(1)
	assert_false(player.path.is_empty())
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.ZERO))
	sim.run_steps(1)
	assert_false(player.path.is_empty(), "zero intent should leave the path alone")
	var before := player.pos
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.RIGHT))
	sim.run_steps(1)
	assert_true(player.path.is_empty(), "non-zero intent should clear the path")
	assert_eq(player.move_intent, Vector2.RIGHT)
	assert_true(player.pos.x > before.x, "person should move only by intent now")
	var intent_pos := player.pos
	sim.run_steps(5)
	assert_true(player.pos.x > intent_pos.x, "person should keep moving by intent")


func test_blocked_waypoint_stops_person_with_path_blocked_once() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	var player := sim.world.player()
	var target := Vector3i(6, 1, 0)
	_walk_to(sim, target)
	sim.run_steps(3)
	assert_false(player.path.is_empty())
	var blocker := Vector3i(5, 1, 0)
	assert_true(sim.world.add_object(_place(sim, "fridge", blocker)))
	sim.events.drain()
	var blocked_count := 0
	for i: int in 300:
		sim.step()
		if MovementSystem.is_box_blocked(sim.world.grid, player.level, player.pos):
			fail("overlapping a blocked cell at step %d, pos %s" % [i, player.pos])
			return
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"path_blocked":
				blocked_count += 1
				assert_eq(event["data"]["person_id"], player.id)
		if player.path.is_empty():
			break
	assert_eq(blocked_count, 1)
	assert_true(player.path.is_empty())
	assert_true(player.cell().x < blocker.x, "stopped inside the blocker: %s" % player.cell())
	var stopped_at := player.pos
	sim.run_steps(20)
	assert_vec_near(player.pos, stopped_at)
	assert_eq(_events_of(sim, &"path_blocked").size(), 0)


func test_facing_points_along_the_walk() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	_walk_to(sim, Vector3i(6, 1, 0))
	sim.run_steps(3)
	assert_eq(sim.world.player().facing, Vector2.RIGHT)


func test_save_and_continue_walk_equals_uninterrupted_run() -> void:
	var straight := SimFactory.from_rows(content(), OPEN_ROOM, 5)
	_walk_to(straight, Vector3i(5, 3, 0))
	straight.run_steps(100)
	var split := SimFactory.from_rows(content(), OPEN_ROOM, 5)
	_walk_to(split, Vector3i(5, 3, 0))
	split.run_steps(30)
	var resumed := SaveCodec.from_json(SaveCodec.to_json(split), content())
	assert_true(resumed != null, "mid-walk save did not load")
	if resumed == null:
		return
	resumed.run_steps(70)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_save_without_path_key_still_loads_empty() -> void:
	var sim := SimFactory.from_rows(content(), OPEN_ROOM)
	_walk_to(sim, Vector3i(5, 3, 0))
	sim.run_steps(5)
	var data := SaveCodec.to_dict(sim)
	var world_data: Dictionary = data["world"]
	var people_data: Array = world_data["people"]
	assert_false(people_data.is_empty())
	(people_data[0] as Dictionary).erase("path")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_dict(data, content(), errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	assert_true(loaded.world.player().path.is_empty())
	loaded.run_steps(10)
