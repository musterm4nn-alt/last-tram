class_name Pathfinder
extends RefCounted
## Walk-route finder over the town grid: one AStarGrid2D per level, with terrain
## path_cost as the cell weight and no corner cutting. A derived cache: it is never
## saved, and each level is rebuilt lazily the first time it is queried after the
## grid changed (WorldGrid.revision).


var _world: World
var _grids: Dictionary[int, AStarGrid2D] = {}
## The grid.revision each level's graph was built at.
var _built_at: Dictionary[int, int] = {}


func _init(p_world: World) -> void:
	_world = p_world


## Cells to walk through after `from`, ending with `to`. Empty if unreachable, if `to`
## or `from` is not walkable, if from == to, or if they are on different levels.
func find_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if from.z != to.z:
		return out
	if from == to:
		return out
	if not _world.grid.is_walkable(from) or not _world.grid.is_walkable(to):
		return out
	var astar := _grid_for(from.z)
	if astar == null:
		return out
	for cell: Vector2i in astar.get_id_path(Vector2i(from.x, from.y), Vector2i(to.x, to.y)):
		out.append(Vector3i(cell.x, cell.y, from.z))
	# get_id_path includes the start cell; the caller already stands on it.
	if not out.is_empty() and out[0] == from:
		out.remove_at(0)
	return out


## True if a person at `from` could walk to `to`. Standing on a walkable cell
## counts as reaching it, even though find_path returns no steps for from == to.
func is_reachable(from: Vector3i, to: Vector3i) -> bool:
	if from.z != to.z:
		return false
	if from == to:
		return _world.grid.is_walkable(from)
	return not find_path(from, to).is_empty()


## The navigation graph for `level`, rebuilt first if the grid changed since.
## Null if the level does not exist.
func _grid_for(level: int) -> AStarGrid2D:
	if not _world.grid.has_level(level):
		return null
	if _grids.has(level) and int(_built_at[level]) == _world.grid.revision:
		return _grids[level] as AStarGrid2D
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, _world.grid.width, _world.grid.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for y: int in _world.grid.height:
		for x: int in _world.grid.width:
			var cell := Vector3i(x, y, level)
			if not _world.grid.is_walkable(cell):
				astar.set_point_solid(Vector2i(x, y), true)
			else:
				astar.set_point_weight_scale(Vector2i(x, y), _world.grid.terrain_def_at(cell).path_cost)
	_grids[level] = astar
	_built_at[level] = _world.grid.revision
	return astar
