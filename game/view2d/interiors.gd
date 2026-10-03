class_name Interiors
extends RefCounted
## The buildings of the town as the view sees them, and which ones are open (T-0086). A
## building is a 4-connected group of indoor cells on one floor; its walls and windows (any
## wall with an indoor cell among its 8 neighbours) belong to it too, so a wall between two
## houses belongs to both. While the player is outside, every building is closed: the view
## draws its roof and hides what is inside. View only; the sim never sees it.

## The interiors of the running game (RoofsView2D rebuilds and updates it). Empty = nothing
## is ever hidden, as in tests that don't build it.
static var current: Interiors = Interiors.new()

## Ids of the buildings that are open now (the player's).
var revealed: PackedInt32Array = PackedInt32Array()

## cell -> ids of the buildings it belongs to
var _owners: Dictionary[Vector3i, PackedInt32Array] = {}
## id -> its cells
var _cells: Array[Array] = []
## id -> its floor
var _levels: PackedInt32Array = PackedInt32Array()


## Finds the buildings on every floor of the grid.
static func build(grid: WorldGrid) -> Interiors:
	var out := Interiors.new()
	for level: int in grid.levels():
		for y: int in grid.height:
			for x: int in grid.width:
				var cell := Vector3i(x, y, level)
				if _indoor(grid, cell) and not out._owners.has(cell):
					out._flood(grid, cell)
	return out


## The number of buildings.
func size() -> int:
	return _cells.size()


## Ids of the buildings `cell` belongs to (empty outdoors).
func buildings_at(cell: Vector3i) -> PackedInt32Array:
	return _owners.get(cell, PackedInt32Array())


func cells(id: int) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(_cells[id])
	return out


func level(id: int) -> int:
	return _levels[id]


## The pixel y of the building's lowest edge (its depth for y-sorting).
func bottom(id: int) -> int:
	var lowest := 0
	for cell: Vector3i in _cells[id]:
		lowest = maxi(lowest, cell.y + 1)
	return lowest * ViewConfig.TILE_PX


## The buildings to open: the player's when they are inside on the viewed floor; when they
## are inside on another floor, the viewed floor's buildings that overlap theirs; else none.
func reveal_for(player_cell: Vector3i, viewed_level: int) -> PackedInt32Array:
	var own := buildings_at(player_cell)  # people stand on floors, which belong to one building
	if own.is_empty() or player_cell.z == viewed_level:
		return own
	var footprint: Dictionary[Vector2i, bool] = {}
	for id: int in own:
		for cell: Vector3i in _cells[id]:
			footprint[Vector2i(cell.x, cell.y)] = true
	var out := PackedInt32Array()
	for id: int in _cells.size():
		if _levels[id] != viewed_level:
			continue
		for cell: Vector3i in _cells[id]:
			if footprint.has(Vector2i(cell.x, cell.y)):
				out.append(id)
				break
	return out


## True when the cell belongs to a building and none of its buildings is open.
func hidden(cell: Vector3i) -> bool:
	var owners := buildings_at(cell)
	if owners.is_empty():
		return false
	for id: int in owners:
		if revealed.has(id):
			return false
	return true


## True when the cell belongs to an open building.
func is_open(cell: Vector3i) -> bool:
	for id: int in buildings_at(cell):
		if revealed.has(id):
			return true
	return false


## True when, with the player inside, the street should drop out of sight: in direct mode only
## (command mode is for watching the town, so it keeps the street but not other interiors).
func shuts_out_street(command_mode: bool) -> bool:
	return not revealed.is_empty() and not command_mode


## True for a wall, window or door whose south neighbour is outside every building: from
## outside it is the building's front, drawn as a face below the roof.
func is_front(grid: WorldGrid, cell: Vector3i) -> bool:
	if buildings_at(cell).is_empty():
		return false
	var terrain := grid.terrain_def_at(cell)
	if terrain.surface != "wall" and terrain.id != WallShapes.DOOR:
		return false
	var south := cell + Vector3i(0, 1, 0)
	return grid.in_bounds(south) and buildings_at(south).is_empty()


## True for a door next to an outdoor cell people can walk on: a way in.
func is_entrance(grid: WorldGrid, cell: Vector3i) -> bool:
	if grid.terrain_def_at(cell).id != WallShapes.DOOR:
		return false
	for side: Vector3i in [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]:
		var next := cell + side
		if grid.in_bounds(next) and buildings_at(next).is_empty() and grid.is_walkable(next):
			return true
	return false


## Fills one building from an indoor cell, then adds its walls.
func _flood(grid: WorldGrid, start: Vector3i) -> void:
	var id := _cells.size()
	var mine: Array[Vector3i] = []
	var todo: Array[Vector3i] = [start]
	_add(start, id)
	while not todo.is_empty():
		var cell: Vector3i = todo.pop_back()
		mine.append(cell)
		for side: Vector3i in [Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(-1, 0, 0)]:
			var next := cell + side
			if _indoor(grid, next) and not _owners.has(next):
				_add(next, id)
				todo.append(next)
	var walls: Dictionary[Vector3i, bool] = {}
	for cell: Vector3i in mine:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var next := cell + Vector3i(dx, dy, 0)
				if grid.in_bounds(next) and grid.terrain_def_at(next).surface == "wall" and not walls.has(next):
					walls[next] = true
					_add(next, id)
	mine.append_array(walls.keys())
	_cells.append(mine)
	_levels.append(start.z)


func _add(cell: Vector3i, id: int) -> void:
	var owners: PackedInt32Array = _owners.get(cell, PackedInt32Array())
	owners.append(id)
	_owners[cell] = owners


static func _indoor(grid: WorldGrid, cell: Vector3i) -> bool:
	return grid.in_bounds(cell) and grid.terrain_def_at(cell).indoor
