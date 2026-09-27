extends TestCase
## T-0003: grid pathfinding around walls and objects, preferring pavements to roads.

const CORRIDOR: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]

const DETOUR: PackedStringArray = [
	"#####",
	"#@#.#",
	"#...#",
	"#...#",
	"#####",
]

## The direct diagonal (1,1) -> (2,2) would cut the corner of the wall at (2,1).
const CORNER: PackedStringArray = [
	"#####",
	"#@###",
	"#..##",
	"#####",
]

const SEALED: PackedStringArray = [
	"#####",
	"#@#.#",
	"#####",
]

const ROAD: PackedStringArray = [
	"########",
	"#,,,,,,#",
	"#@====.#",
	"#,,,,,,#",
	"########",
]

const PILLARS: PackedStringArray = [
	"########",
	"#@..#..#",
	"#...#..#",
	"#..##..#",
	"#......#",
	"########",
]

## The Späti's shop entrance: north door of spaeti_kaya, facing the Hauptstraße.
const SPAETI_DOOR: Vector3i = Vector3i(5, 23, 0)


## Every cell walkable, last cell is the goal, steps are king moves, start excluded.
func _walkable_path(sim: Sim, path: Array[Vector3i], from: Vector3i, to: Vector3i) -> void:
	assert_false(path.is_empty(), "no path from %s to %s" % [from, to])
	if path.is_empty():
		return
	assert_eq(path[path.size() - 1], to)
	assert_false(path.has(from), "path includes the start %s" % from)
	var prev := from
	for cell: Vector3i in path:
		assert_true(sim.world.grid.is_walkable(cell), "%s is not walkable" % cell)
		var step := cell - prev
		assert_true(step.z == 0 and absi(step.x) <= 1 and absi(step.y) <= 1 and (step.x != 0 or step.y != 0), "not neighbours: %s -> %s" % [prev, cell])
		prev = cell


## A diagonal step needs both orthogonal neighbours free (no corner cutting).
func _no_corner_cuts(sim: Sim, path: Array[Vector3i], from: Vector3i) -> void:
	var prev := from
	for cell: Vector3i in path:
		var step := cell - prev
		if step.x != 0 and step.y != 0:
			assert_true(sim.world.grid.is_walkable(Vector3i(prev.x + step.x, prev.y, prev.z)), "diagonal %s -> %s cuts a blocked corner" % [prev, cell])
			assert_true(sim.world.grid.is_walkable(Vector3i(prev.x, prev.y + step.y, prev.z)), "diagonal %s -> %s cuts a blocked corner" % [prev, cell])
		prev = cell


func test_straight_corridor_gives_straight_path_without_the_start() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	var path := sim.nav.find_path(Vector3i(1, 1, 0), Vector3i(3, 1, 0))
	assert_eq(path.size(), 2)
	assert_eq(path[0], Vector3i(2, 1, 0))
	assert_eq(path[1], Vector3i(3, 1, 0))
	assert_true(sim.nav.is_reachable(Vector3i(1, 1, 0), Vector3i(3, 1, 0)))


func test_wall_between_gives_a_walkable_path_around_it() -> void:
	var sim := SimFactory.from_rows(content(), DETOUR)
	var from := Vector3i(1, 1, 0)
	var to := Vector3i(3, 1, 0)
	var path := sim.nav.find_path(from, to)
	_walkable_path(sim, path, from, to)
	_no_corner_cuts(sim, path, from)
	assert_true(path.size() > 2, "must detour around the wall, got %s" % [path])


func test_diagonal_step_never_cuts_a_blocked_corner() -> void:
	var sim := SimFactory.from_rows(content(), CORNER)
	var from := Vector3i(1, 1, 0)
	var to := Vector3i(2, 2, 0)
	var path := sim.nav.find_path(from, to)
	# (2,1) is a wall, so the direct diagonal is forbidden: around the corner.
	assert_eq(path.size(), 2)
	assert_eq(path[0], Vector3i(1, 2, 0))
	assert_eq(path[1], to)
	_walkable_path(sim, path, from, to)
	_no_corner_cuts(sim, path, from)


func test_pillar_map_paths_never_cut_corners() -> void:
	var sim := SimFactory.from_rows(content(), PILLARS)
	var pairs: Array[Array] = [
		[Vector3i(1, 1, 0), Vector3i(6, 4, 0)],
		[Vector3i(1, 1, 0), Vector3i(6, 1, 0)],
		[Vector3i(6, 4, 0), Vector3i(1, 4, 0)],
	]
	for pair: Array in pairs:
		var from: Vector3i = pair[0]
		var to: Vector3i = pair[1]
		var path := sim.nav.find_path(from, to)
		_walkable_path(sim, path, from, to)
		_no_corner_cuts(sim, path, from)


func test_unreachable_goal_in_wall_same_cell_and_other_level_are_empty() -> void:
	var sim := SimFactory.from_rows(content(), SEALED)
	var from := Vector3i(1, 1, 0)
	# Walled in: the goal across the wall cannot be reached.
	assert_true(sim.nav.find_path(from, Vector3i(3, 1, 0)).is_empty())
	assert_false(sim.nav.is_reachable(from, Vector3i(3, 1, 0)))
	# Goal inside a wall.
	assert_true(sim.nav.find_path(from, Vector3i(2, 1, 0)).is_empty())
	assert_false(sim.nav.is_reachable(from, Vector3i(2, 1, 0)))
	# Start inside a wall cannot go anywhere either.
	assert_true(sim.nav.find_path(Vector3i(0, 0, 0), from).is_empty())
	# From == to needs no steps...
	assert_true(sim.nav.find_path(from, from).is_empty())
	# ...but standing on a walkable cell counts as reaching it.
	assert_true(sim.nav.is_reachable(from, from))
	assert_false(sim.nav.is_reachable(Vector3i(0, 0, 0), Vector3i(0, 0, 0)))
	# Other levels are out of reach, even an unknown one.
	assert_true(sim.nav.find_path(from, Vector3i(1, 1, 1)).is_empty())
	assert_false(sim.nav.is_reachable(from, Vector3i(1, 1, 1)))


func test_levels_route_on_their_own_but_never_between_each_other() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	var floor_index := content().terrain_index("floor_wood")
	sim.world.grid.ensure_level(1)
	for x: int in [1, 2, 3]:
		sim.world.grid.set_terrain(Vector3i(x, 1, 1), floor_index)
	assert_true(sim.nav.find_path(Vector3i(1, 1, 0), Vector3i(1, 1, 1)).is_empty())
	var upper := sim.nav.find_path(Vector3i(1, 1, 1), Vector3i(3, 1, 1))
	assert_eq(upper.size(), 2)
	assert_eq(upper[1], Vector3i(3, 1, 1))


func test_pavement_detour_beats_the_road_shortcut() -> void:
	var sim := SimFactory.from_rows(content(), ROAD)
	var from := Vector3i(1, 2, 0)
	var to := Vector3i(6, 2, 0)
	var path := sim.nav.find_path(from, to)
	_walkable_path(sim, path, from, to)
	# Diagonals make the detour the same step count as the road, but far cheaper,
	# so the criterion is simply: not one step of road.
	for cell: Vector3i in path:
		assert_false(sim.world.grid.terrain_def_at(cell).id == "road", "path jaywalks at %s" % cell)


func test_blocking_object_forces_a_rebuild_and_removal_restores() -> void:
	var sim := SimFactory.from_rows(content(), CORRIDOR)
	var from := Vector3i(1, 1, 0)
	var to := Vector3i(3, 1, 0)
	assert_eq(sim.nav.find_path(from, to).size(), 2)
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = "fridge"
	obj.origin = Vector3i(2, 1, 0)
	obj.rotation = 0
	assert_true(sim.world.add_object(obj))
	# The corridor is shut: only a rebuilt graph knows it.
	assert_true(sim.nav.find_path(from, to).is_empty())
	assert_false(sim.nav.is_reachable(from, to))
	sim.world.remove_object(obj.id)
	var restored := sim.nav.find_path(from, to)
	assert_eq(restored.size(), 2)
	assert_eq(restored[0], Vector3i(2, 1, 0))
	assert_eq(restored[1], to)


func test_altstadt_spawn_reaches_the_spaeti_door() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var from: Vector3i = content().districts["altstadt"].player_spawn
	assert_true(sim.world.grid.is_walkable(from), "spawn %s is not walkable" % from)
	assert_true(sim.world.grid.is_walkable(SPAETI_DOOR), "spaeti door %s is not walkable" % SPAETI_DOOR)
	var path := sim.nav.find_path(from, SPAETI_DOOR)
	_walkable_path(sim, path, from, SPAETI_DOOR)
	_no_corner_cuts(sim, path, from)


func test_game_terrain_path_costs_match_spec() -> void:
	var db := content()
	assert_near(db.terrains[db.terrain_index("sidewalk")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("cobblestone")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("floor_wood")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("door")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("bridge")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("crossing")].path_cost, 1.0)
	assert_near(db.terrains[db.terrain_index("grass")].path_cost, 1.5)
	assert_near(db.terrains[db.terrain_index("road")].path_cost, 4.0)
	assert_near(db.terrains[db.terrain_index("tram_track")].path_cost, 4.0)
	for t: TerrainDef in db.terrains:
		assert_true(t.path_cost >= 1.0, "'%s' costs %s" % [t.id, t.path_cost])


func test_terrain_without_path_cost_is_reported() -> void:
	var db := ContentDB.new()
	var reader := ContentReader.new()
	TerrainLoader.load(db, reader, "res://tests/fixtures/content_broken/terrain.json")
	var all := "\n".join(reader.errors)
	assert_true(all.contains("path_cost"), "missing cost not reported: " + all)


func test_terrain_with_path_cost_below_one_is_reported() -> void:
	var db := ContentDB.new()
	var reader := ContentReader.new()
	TerrainLoader.load(db, reader, "res://tests/fixtures/terrain_bad_cost.json")
	assert_eq(reader.errors.size(), 1)
	assert_true(reader.errors[0].contains("path_cost"), reader.errors[0])
	assert_true(reader.errors[0].contains(">= 1.0"), reader.errors[0])
