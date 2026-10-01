extends TestCase
## T-0047: holding Shift runs at Person.RUN_FACTOR times the walking speed.

const STEPS: int = SimClock.STEPS_PER_GAME_MINUTE
const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"

const ROOM: PackedStringArray = [
	"################",
	"#..............#",
	"#...@..........#",
	"#..............#",
	"################",
]


func _sim(running: bool) -> Sim:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.submit(SetRunningCommand.new(sim.world.player_id, running))
	return sim


func test_running_with_direct_control_covers_twice_the_walking_distance() -> void:
	var sim := _sim(true)
	var player := sim.world.player()
	var start := player.pos
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	sim.run_steps(STEPS)
	assert_true(player.running)
	assert_vec_near(player.pos, start + Vector2(player.walk_speed * 2.0, 0.0), 0.0001)


func test_walking_speed_is_unchanged_after_running_stops() -> void:
	var sim := _sim(true)
	var player := sim.world.player()
	sim.step()
	sim.submit(SetRunningCommand.new(player.id, false))
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	var start := player.pos
	sim.run_steps(STEPS)
	assert_false(player.running)
	assert_vec_near(player.pos, start + Vector2(player.walk_speed, 0.0), 0.0001)


func test_running_along_a_path_is_twice_as_fast_as_walking_it() -> void:
	var distances: Array[float] = []
	for running: bool in [false, true]:
		var sim := _sim(running)
		var player := sim.world.player()
		var start := player.pos
		sim.submit(WalkToCommand.new(player.id, Vector3i(14, 2, 0)))
		sim.run_steps(STEPS)
		assert_false(player.path.is_empty(), "still on the way after one minute")
		distances.append(player.pos.distance_to(start))
	assert_near(distances[0], content_walk_speed(), 0.0001)
	assert_near(distances[1], distances[0] * 2.0, 0.0001)


func test_running_into_a_wall_stops_before_it() -> void:
	var sim := _sim(true)
	var player := sim.world.player()
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	sim.run_minutes(5)
	assert_true(player.pos.x < 15.0 - Person.RADIUS, "stopped before the wall")
	assert_true(player.pos.x > 14.0, "reached the wall")


func test_running_survives_saving_and_loading() -> void:
	var sim := _sim(true)
	sim.step()
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	assert_true(loaded.world.player().running)


func test_a_pending_running_command_survives_saving() -> void:
	var sim := _sim(true)
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	loaded.step()
	assert_true(loaded.world.player().running)


func test_an_old_save_without_running_loads_as_walking() -> void:
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	assert_true(sim != null)
	for person: Person in sim.world.people.values():
		assert_false(person.running)
		assert_eq(person.move_speed(), person.walk_speed)


func test_a_non_boolean_running_value_is_rejected() -> void:
	var sim := _sim(false)
	sim.step()
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	for person: Variant in data["world"]["people"]:
		(person as Dictionary)["running"] = "yes"
	assert_eq(SaveCodec.from_json(JSON.stringify(data), content()), null)


func content_walk_speed() -> float:
	return Person.new().walk_speed
