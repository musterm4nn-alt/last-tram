extends TestCase

const STEPS: int = SimClock.STEPS_PER_GAME_MINUTE

const ROOM: PackedStringArray = [
	"################",
	"#..............#",
	"#...@..........#",
	"#..............#",
	"################",
]

const PILLARS: PackedStringArray = [
	"##########",
	"#........#",
	"#.#..#.#.#",
	"#...@....#",
	"#.##...#.#",
	"#......#.#",
	"##########",
]


func _walk(sim: Sim, direction: Vector2) -> void:
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, direction))


func test_standing_still_does_not_move() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var start := sim.world.player().pos
	sim.run_steps(STEPS)
	assert_vec_near(sim.world.player().pos, start)


func test_walks_walk_speed_cells_per_minute() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var start := player.pos
	_walk(sim, Vector2.RIGHT)
	sim.run_steps(STEPS)
	assert_vec_near(player.pos, start + Vector2(player.walk_speed, 0.0), 0.000001)


func test_diagonal_is_not_faster() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var start := player.pos
	_walk(sim, Vector2(1, 1))
	sim.run_steps(5)
	assert_near(player.pos.distance_to(start), player.walk_speed * 5.0 / STEPS, 0.000001)


func test_wall_stops_person_just_before_it() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	_walk(sim, Vector2.RIGHT)
	sim.run_minutes(5)
	# The east wall is cell x=15, so the box edge (pos.x + RADIUS) must stay below 15.
	assert_true(player.pos.x + Person.RADIUS < 15.0, "box overlaps the wall")
	assert_true(player.pos.x + Person.RADIUS > 14.99, "stopped too early: %s" % player.pos.x)


func test_slides_along_wall_when_walking_diagonally_into_it() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var start := player.pos
	_walk(sim, Vector2(1, -1))
	sim.run_minutes(1)
	assert_true(player.pos.y - Person.RADIUS > 1.0, "entered the north wall")
	assert_true(player.pos.x > start.x + 2.0, "should keep sliding east along the wall")


func test_stop_command_stops() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	_walk(sim, Vector2.RIGHT)
	sim.run_steps(4)
	_walk(sim, Vector2.ZERO)
	sim.run_steps(1)
	var stopped_at := player.pos
	sim.run_steps(STEPS)
	assert_vec_near(player.pos, stopped_at)


func test_facing_follows_the_main_direction() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	_walk(sim, Vector2(-0.3, 0.9))
	sim.run_steps(1)
	assert_eq(sim.world.player().facing, Vector2.DOWN)
	_walk(sim, Vector2(-1, 0.2))
	sim.run_steps(1)
	assert_eq(sim.world.player().facing, Vector2.LEFT)


## Property test: whatever the input, a person never overlaps a blocked cell.
func test_random_walk_never_enters_blocked_cells() -> void:
	var sim := SimFactory.from_rows(content(), PILLARS)
	var player := sim.world.player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i: int in 3000:
		if i % 15 == 0:
			_walk(sim, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
		sim.step()
		if MovementSystem.is_box_blocked(sim.world.grid, player.level, player.pos):
			fail("overlapping a blocked cell at step %d, pos %s" % [i, player.pos])
			return


func test_command_for_unknown_person_is_ignored() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.submit(SetMoveIntentCommand.new(9999, Vector2.RIGHT))
	sim.run_steps(STEPS)
	assert_eq(sim.world.player().move_intent, Vector2.ZERO)
