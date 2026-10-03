extends TestCase
## T-0086: buildings are found per floor, the player's building opens, the rest stay closed
## behind roofs, and fronts and entrances are known.

## Two houses sharing a wall (x 5), a door from each onto the square; the west house has a
## front door in its south wall too.
const ROWS: PackedStringArray = [
	"::::::::::::",
	":#####D###::",
	":#...#...#::",
	":#.@.#...#::",
	":##D######::",
	"::::::::::::",
]

var _old: Interiors


func before_each() -> void:
	_old = Interiors.current


func after_each() -> void:
	Interiors.current = _old


func _grid() -> WorldGrid:
	return SimFactory.from_rows(content(), ROWS).world.grid


func test_buildings_and_shared_walls() -> void:
	var interiors := Interiors.build(_grid())
	assert_eq(interiors.size(), 2)
	var west := interiors.buildings_at(Vector3i(2, 2, 0))
	var east := interiors.buildings_at(Vector3i(7, 2, 0))
	assert_eq(west.size(), 1)
	assert_eq(east.size(), 1)
	assert_ne(west[0], east[0])
	assert_eq(interiors.buildings_at(Vector3i(5, 2, 0)).size(), 2, "the shared wall belongs to both")
	assert_eq(interiors.buildings_at(Vector3i(3, 4, 0)), west, "the front door is part of the west house")
	assert_eq(interiors.buildings_at(Vector3i(0, 0, 0)).size(), 0, "the square")
	assert_eq(interiors.bottom(west[0]), 5 * ViewConfig.TILE_PX, "lowest edge: below row 4")
	assert_eq(interiors.level(east[0]), 0)


func test_reveal_for() -> void:
	var interiors := Interiors.build(_grid())
	var west := interiors.buildings_at(Vector3i(2, 2, 0))[0]
	assert_eq(interiors.reveal_for(Vector3i(3, 3, 0), 0), PackedInt32Array([west]), "inside")
	assert_eq(interiors.reveal_for(Vector3i(3, 4, 0), 0), PackedInt32Array([west]), "in the doorway")
	assert_eq(interiors.reveal_for(Vector3i(0, 5, 0), 0).size(), 0, "outside")


func test_reveal_on_another_floor() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var interiors := Interiors.build(sim.world.grid)
	var stairwell := Vector3i(10, 28, 0)  # Haus 3's ground-floor stairs (level_0 '^')
	assert_eq(sim.world.grid.terrain_def_at(stairwell).id, "stairs")
	var upstairs := interiors.reveal_for(stairwell, 1)
	assert_true(upstairs.size() >= 1, "the floor above in the same house opens")
	for id: int in upstairs:
		assert_eq(interiors.level(id), 1)
	assert_eq(interiors.reveal_for(Vector3i(30, 28, 0), 1).size(), 0, "from the square, nothing opens upstairs")


func test_hidden_front_and_entrances() -> void:
	var grid := _grid()
	var interiors := Interiors.build(grid)
	interiors.revealed = interiors.reveal_for(Vector3i(3, 3, 0), 0)
	assert_false(interiors.hidden(Vector3i(2, 2, 0)), "the open house")
	assert_true(interiors.hidden(Vector3i(7, 2, 0)), "the other house")
	assert_false(interiors.hidden(Vector3i(5, 2, 0)), "the shared wall shows with the open house")
	assert_false(interiors.hidden(Vector3i(0, 0, 0)), "outdoors is never hidden")
	assert_true(interiors.is_open(Vector3i(2, 2, 0)))
	assert_false(interiors.is_open(Vector3i(0, 0, 0)))
	interiors.revealed = PackedInt32Array()
	assert_true(interiors.hidden(Vector3i(5, 2, 0)), "the shared wall hides when both are closed")
	assert_true(interiors.is_front(grid, Vector3i(2, 4, 0)), "south wall")
	assert_true(interiors.is_front(grid, Vector3i(3, 4, 0)), "south door")
	assert_false(interiors.is_front(grid, Vector3i(6, 1, 0)), "north door")
	assert_false(interiors.is_front(grid, Vector3i(5, 2, 0)), "inner wall")
	assert_true(interiors.is_entrance(grid, Vector3i(6, 1, 0)), "north door onto the square")
	assert_true(interiors.is_entrance(grid, Vector3i(3, 4, 0)), "south door onto the square")
	assert_false(interiors.is_entrance(grid, Vector3i(2, 2, 0)), "a floor")


func test_street_shut_out_only_in_direct_mode() -> void:
	var interiors := Interiors.build(_grid())
	assert_false(interiors.shuts_out_street(false), "outside")
	interiors.revealed = interiors.reveal_for(Vector3i(3, 3, 0), 0)
	assert_true(interiors.shuts_out_street(false), "inside, direct mode")
	assert_false(interiors.shuts_out_street(true), "inside, command mode: watching the town")
