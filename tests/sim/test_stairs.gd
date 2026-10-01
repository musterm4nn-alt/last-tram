extends TestCase
## T-0030: stairs link a floor with the one above; routes and walking cross them.

const GROUND: PackedStringArray = [
	"##########",
	"#@.......#",
	"#.......^#",
	"##########",
]
const UPSTAIRS: PackedStringArray = [
	"##########",
	"#...#....#",
	"#.......^#",
	"##########",
]
const UPSTAIRS_NO_STAIRS: PackedStringArray = [
	"##########",
	"#........#",
	"#........#",
	"##########",
]


func _two_floors(upper: PackedStringArray = UPSTAIRS) -> Sim:
	var sim := SimFactory.from_rows(content(), GROUND)
	sim.world.grid.stamp_rows(1, Vector2i.ZERO, upper)
	return sim


## Fails unless every step of `path` (after `from`) is a neighbour on one level or a hop
## between the two stairs ends of a link, and it ends at `to`.
func _assert_valid_route(sim: Sim, from: Vector3i, to: Vector3i, path: Array[Vector3i]) -> void:
	assert_false(path.is_empty(), "a route exists")
	if path.is_empty():
		return
	assert_eq(path[path.size() - 1], to)
	var prev := from
	for cell: Vector3i in path:
		var step := cell - prev
		var neighbour := step.z == 0 and absi(step.x) <= 1 and absi(step.y) <= 1 and step != Vector3i.ZERO
		var hop := step.x == 0 and step.y == 0 and absi(step.z) == 1 \
			and sim.world.grid.terrain_def_at(prev).id == "stairs" and sim.world.grid.terrain_def_at(cell).id == "stairs"
		assert_true(neighbour or hop, "bad step %s -> %s" % [prev, cell])
		assert_true(sim.world.grid.is_walkable(cell), "%s is walkable" % cell)
		prev = cell


func test_a_route_to_the_floor_above_goes_through_the_stairs() -> void:
	var sim := _two_floors()
	var from := Vector3i(1, 1, 0)
	var to := Vector3i(2, 1, 1)
	var path := sim.nav.find_path(from, to)
	_assert_valid_route(sim, from, to, path)
	assert_has(path, Vector3i(8, 2, 0))
	assert_has(path, Vector3i(8, 2, 1))
	assert_true(sim.nav.is_reachable(from, to))


func test_a_route_down_mirrors_the_route_up() -> void:
	var sim := _two_floors()
	var from := Vector3i(2, 1, 1)
	var to := Vector3i(1, 1, 0)
	_assert_valid_route(sim, from, to, sim.nav.find_path(from, to))


func test_without_stairs_above_the_upper_floor_is_unreachable() -> void:
	var sim := _two_floors(UPSTAIRS_NO_STAIRS)
	var from := Vector3i(1, 1, 0)
	var to := Vector3i(2, 1, 1)
	assert_true(sim.nav.find_path(from, to).is_empty())
	assert_false(sim.nav.is_reachable(from, to))


func test_the_route_uses_the_cheaper_of_two_stairs() -> void:
	var sim := SimFactory.from_rows(content(), [
		"############",
		"#^...@....^#",
		"############",
	])
	sim.world.grid.stamp_rows(1, Vector2i.ZERO, [
		"############",
		"#^........^#",
		"############",
	])
	var from := Vector3i(5, 1, 0)
	var to := Vector3i(9, 1, 1)
	var path := sim.nav.find_path(from, to)
	_assert_valid_route(sim, from, to, path)
	assert_has(path, Vector3i(10, 1, 1), "the near stairs")
	assert_false(path.has(Vector3i(1, 1, 1)), "not the far stairs")
	# And the other way round: a target near the left stairs uses those.
	var left := sim.nav.find_path(Vector3i(3, 1, 0), Vector3i(2, 1, 1))
	assert_has(left, Vector3i(1, 1, 1))


func test_a_level_split_in_two_is_joined_through_the_floor_below() -> void:
	var sim := SimFactory.from_rows(content(), [
		"##########",
		"#^@.....^#",
		"##########",
	])
	sim.world.grid.stamp_rows(1, Vector2i.ZERO, [
		"##########",
		"#^..##..^#",
		"##########",
	])
	var from := Vector3i(2, 1, 1)
	var to := Vector3i(7, 1, 1)
	var path := sim.nav.find_path(from, to)
	_assert_valid_route(sim, from, to, path)
	assert_has(path, Vector3i(5, 1, 0), "down, across and up again")


func test_walking_upstairs_ends_on_the_upper_floor_without_touching_walls() -> void:
	var sim := _two_floors()
	var player := sim.world.player()
	sim.submit(WalkToCommand.new(player.id, Vector3i(2, 1, 1)))
	var changed_level_at := -1
	for i: int in SimClock.STEPS_PER_GAME_MINUTE * 5:
		sim.step()
		assert_false(MovementSystem.is_box_blocked(sim.world.grid, player.level, player.pos),
			"overlaps a blocked cell at %s on level %d" % [player.pos, player.level])
		if player.level == 1 and changed_level_at < 0:
			changed_level_at = i
			assert_eq(player.cell(), Vector3i(8, 2, 1), "arrives at the top of the stairs")
	assert_true(changed_level_at >= 0, "went up")
	assert_eq(player.level, 1)
	assert_eq(player.cell(), Vector3i(2, 1, 1))
	assert_true(player.path.is_empty())


func test_saving_mid_climb_and_continuing_equals_an_uninterrupted_run() -> void:
	var straight := _two_floors()
	straight.submit(WalkToCommand.new(straight.world.player_id, Vector3i(2, 1, 1)))
	straight.run_steps(200)
	for cut: int in [20, 37, 41, 45]:
		var first := _two_floors()
		first.submit(WalkToCommand.new(first.world.player_id, Vector3i(2, 1, 1)))
		first.run_steps(cut)
		var resumed := SaveCodec.from_json(SaveCodec.to_json(first), content())
		assert_true(resumed != null)
		resumed.run_steps(200 - cut)
		assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight), "cut at step %d" % cut)


func test_stairs_terrain_loads_without_content_errors() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	var stairs := content().terrain(content().terrain_index_for_glyph("^"))
	assert_eq(stairs.id, "stairs")
	assert_true(stairs.walkable)
	assert_eq(stairs.path_cost, 2.0)
