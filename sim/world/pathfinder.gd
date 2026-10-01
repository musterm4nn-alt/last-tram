class_name Pathfinder
extends RefCounted
## Walk-route finder over the town grid: one AStarGrid2D per level, with terrain
## path_cost as the cell weight and no corner cutting, plus stair links between levels.
## A derived cache: it is never saved, and each level is rebuilt lazily the first time it
## is queried after the grid changed (WorldGrid.revision).
##
## Stair link: a walkable stairs cell at (x, y, L) links to (x, y, L + 1) when that cell is
## walkable stairs too; a route crosses a link as one step costing LINK_COST. Routes between
## levels (or between parts of a level joined only through another level) are a Dijkstra
## over stair cells, where moving within a level costs the A* path cost.

## Terrain id of stairs cells.
const STAIRS: String = "stairs"
## Route cost of one hop along a stair link.
const LINK_COST: float = 2.0

var _world: World
var _grids: Dictionary[int, AStarGrid2D] = {}
## The grid.revision each level's graph was built at.
var _built_at: Dictionary[int, int] = {}
## Linked stairs cells per level (scan order), built with that level's graph.
var _stairs: Dictionary[int, Array] = {}
## Segments between two stairs cells: "a|b" -> {"cost": float, "path": Array[Vector3i]}.
## Cleared whenever the grid changes.
var _segments: Dictionary[String, Dictionary] = {}
var _segments_revision: int = -1


func _init(p_world: World) -> void:
	_world = p_world


## Cells to walk through after `from`, ending with `to`. A stair hop appears as the stairs
## cell at the other end of the link. Empty if unreachable, if `to` or `from` is not
## walkable, or if from == to.
func find_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if from == to:
		return out
	if not _world.grid.is_walkable(from) or not _world.grid.is_walkable(to):
		return out
	if from.z == to.z:
		out.assign(_segment(from, to)["path"])  # a copy: callers consume their path
		if not out.is_empty():
			return out
	return _route_across_levels(from, to)


## True if a person at `from` could walk to `to`. Standing on a walkable cell
## counts as reaching it, even though find_path returns no steps for from == to.
func is_reachable(from: Vector3i, to: Vector3i) -> bool:
	if from == to:
		return _world.grid.is_walkable(from)
	return not find_path(from, to).is_empty()


## The in-level A* route from `a` to `b` (same level): {"cost": float (INF if none),
## "path": Array[Vector3i] (excluding a)}. Routes between two stairs cells are cached.
func _segment(a: Vector3i, b: Vector3i) -> Dictionary:
	if _segments_revision != _world.grid.revision:
		_segments.clear()
		_segments_revision = _world.grid.revision
	var key := "%s|%s" % [a, b]
	if _segments.has(key):
		return _segments[key]
	var path: Array[Vector3i] = []
	var cost := INF
	var astar := _grid_for(a.z)
	if astar != null:
		var cells := astar.get_id_path(Vector2i(a.x, a.y), Vector2i(b.x, b.y))
		if cells.size() > 1:
			cost = 0.0
			for i: int in range(1, cells.size()):
				cost += Vector2(cells[i] - cells[i - 1]).length() * astar.get_point_weight_scale(cells[i])
				path.append(Vector3i(cells[i].x, cells[i].y, a.z))
	var result := {"cost": cost, "path": path}
	if _is_stairs(a) and _is_stairs(b):
		_segments[key] = result
	return result


## Dijkstra over stair cells (plus `from` and `to`): within a level, edges cost the A*
## route; across a link, LINK_COST. Returns the concatenated cells, or [] if unreachable.
func _route_across_levels(from: Vector3i, to: Vector3i) -> Array[Vector3i]:
	var dist: Dictionary[Vector3i, float] = {from: 0.0}
	# node -> [previous node, hop?]
	var came: Dictionary[Vector3i, Array] = {}
	var open: Array[Vector3i] = [from]
	var done: Dictionary[Vector3i, bool] = {}
	while not open.is_empty():
		var best := 0
		for i: int in range(1, open.size()):
			if dist[open[i]] < dist[open[best]]:
				best = i
		var node: Vector3i = open[best]
		open.remove_at(best)
		if done.has(node):
			continue
		done[node] = true
		if node == to:
			return _unwind(came, to)
		var next: Array[Vector3i] = []
		next.assign(_stairs_on(node.z))
		if to.z == node.z:
			next.append(to)
		for other: Vector3i in next:
			if other != node and not done.has(other):
				_relax(node, other, dist[node] + _segment(node, other)["cost"], false, dist, came, open)
		for dz: int in [1, -1]:
			var linked := Vector3i(node.x, node.y, node.z + dz)
			if is_stair_link(node, linked) and not done.has(linked):
				_relax(node, linked, dist[node] + LINK_COST, true, dist, came, open)
	var none: Array[Vector3i] = []
	return none


static func _relax(from: Vector3i, to: Vector3i, cost: float, hop: bool, dist: Dictionary[Vector3i, float],
		came: Dictionary[Vector3i, Array], open: Array[Vector3i]) -> void:
	if cost == INF or (dist.has(to) and dist[to] <= cost):
		return
	dist[to] = cost
	came[to] = [from, hop]
	open.append(to)


## The cells of the route that ended at `to`, rebuilt from Dijkstra's back links.
func _unwind(came: Dictionary[Vector3i, Array], to: Vector3i) -> Array[Vector3i]:
	var legs: Array[Array] = []
	var node := to
	while came.has(node):
		legs.push_front([came[node][0], node, came[node][1]])
		node = came[node][0]
	var out: Array[Vector3i] = []
	for leg: Array in legs:
		if leg[2]:
			out.append(leg[1])
		else:
			out.append_array(_segment(leg[0], leg[1])["path"])
	return out


func _is_stairs(cell: Vector3i) -> bool:
	return _world.grid.terrain_def_at(cell).id == STAIRS and _world.grid.is_walkable(cell)


## True if `a` and `b` are the two ends of a stair link (same x, y, one level apart, both
## walkable stairs).
func is_stair_link(a: Vector3i, b: Vector3i) -> bool:
	return a.x == b.x and a.y == b.y and absi(a.z - b.z) == 1 and _is_stairs(a) and _is_stairs(b)


## Linked stairs cells on `level`, in scan order.
func _stairs_on(level: int) -> Array:
	if _grid_for(level) == null:
		return []
	return _stairs[level]


## The navigation graph for `level`, rebuilt first if the grid changed since.
## Null if the level does not exist.
func _grid_for(level: int) -> AStarGrid2D:
	if not _world.grid.has_level(level):
		return null
	if _grids.has(level) and _built_at[level] == _world.grid.revision:
		return _grids[level]
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, _world.grid.width, _world.grid.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var stairs: Array[Vector3i] = []
	for y: int in _world.grid.height:
		for x: int in _world.grid.width:
			var cell := Vector3i(x, y, level)
			if not _world.grid.is_walkable(cell):
				astar.set_point_solid(Vector2i(x, y), true)
			else:
				astar.set_point_weight_scale(Vector2i(x, y), _world.grid.terrain_def_at(cell).path_cost)
				if is_stair_link(cell, cell + Vector3i(0, 0, 1)) or is_stair_link(cell, cell - Vector3i(0, 0, 1)):
					stairs.append(cell)
	_stairs[level] = stairs
	_grids[level] = astar
	_built_at[level] = _world.grid.revision
	return astar
