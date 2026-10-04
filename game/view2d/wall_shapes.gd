class_name WallShapes
extends RefCounted
## How each wall, window and door cell is drawn in the 3/4 view (T-0085). The wall along the
## top of a room shows its FACE (the plaster, a window, a front door: the cell's tile), and so
## do the corners and junctions at the ends of that wall; every
## other wall is a THIN line through its cell with ground beside it; a door in such a wall is
## a DOORWAY. Pure functions of the grid; the sim still treats walls as whole cells.

const NONE: int = 0
const FACE: int = 1
const THIN: int = 2
const DOORWAY: int = 3

const ARM_N: int = 1
const ARM_E: int = 2
const ARM_S: int = 4
const ARM_W: int = 8

const DOOR: String = "door"


## FACE, THIN, DOORWAY or NONE for a cell.
static func kind(grid: WorldGrid, cell: Vector3i) -> int:
	if not grid.in_bounds(cell):
		return NONE
	var terrain := grid.terrain_def_at(cell)
	if terrain.surface == "wall":
		var south := cell + Vector3i(0, 1, 0)
		if _faces_room(grid, cell):
			return FACE
		if not _near_indoor(grid, cell):
			return THIN if _walled(grid, south) else FACE
		# A corner or T-junction in a top wall carries the face on, and the wall below it
		# starts under the face (the owner's playtest, 3 October: corners poked out).
		if terrain.id == "wall" and _walled(grid, south):  # a window there stays in its side wall
			for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
				if _faces_room(grid, cell + side):
					return FACE
		return THIN
	if terrain.id == DOOR:
		for side: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0)]:
			var next := cell + side
			if grid.in_bounds(next) and grid.terrain_def_at(next).surface == "wall" and kind(grid, next) == FACE:
				return FACE
		return DOORWAY
	return NONE


## Which sides (ARM_E, ARM_W) of a FACE cell to trim back to the thin wall's edge (T-0089): a
## face with a thin wall or doorway below it is a corner or junction, and on a side with no
## wall beside it (the street, a yard) the full-width face would stick out past that wall.
static func face_trim(grid: WorldGrid, cell: Vector3i) -> int:
	if kind(grid, cell) != FACE:
		return 0
	var below := kind(grid, cell + Vector3i(0, 1, 0))
	if below != THIN and below != DOORWAY:
		return 0
	var mask := 0
	if not _walled(grid, cell + Vector3i(1, 0, 0)):
		mask |= ARM_E
	if not _walled(grid, cell + Vector3i(-1, 0, 0)):
		mask |= ARM_W
	return mask


## Bitmask (ARM_N, ARM_E, ARM_S, ARM_W) of the neighbours that are walls, windows or doors.
static func arms(grid: WorldGrid, cell: Vector3i) -> int:
	var mask := 0
	if _walled(grid, cell + Vector3i(0, -1, 0)):
		mask |= ARM_N
	if _walled(grid, cell + Vector3i(1, 0, 0)):
		mask |= ARM_E
	if _walled(grid, cell + Vector3i(0, 1, 0)):
		mask |= ARM_S
	if _walled(grid, cell + Vector3i(-1, 0, 0)):
		mask |= ARM_W
	return mask


## The cell whose ground fills quadrant 0 NW, 1 NE, 2 SW, 3 SE of a thin wall or doorway: the
## first of the horizontal neighbour, the vertical neighbour and the diagonal on that side
## that isn't a wall, window or door; the cell itself when all three are.
static func quadrant_ground(grid: WorldGrid, cell: Vector3i, quadrant: int) -> Vector3i:
	var dx := 1 if quadrant % 2 == 1 else -1
	var dy := 1 if quadrant >= 2 else -1
	for offset: Vector3i in [Vector3i(dx, 0, 0), Vector3i(0, dy, 0), Vector3i(dx, dy, 0)]:
		var next := cell + offset
		if grid.in_bounds(next) and not _walled(grid, next):
			return next
	return cell


## True for a wall or window with a room right below it (not a door): it shows its face.
static func _faces_room(grid: WorldGrid, cell: Vector3i) -> bool:
	if not grid.in_bounds(cell) or grid.terrain_def_at(cell).surface != "wall":
		return false
	var south := cell + Vector3i(0, 1, 0)
	return _indoor(grid, south) and not _is_door(grid, south)


## True for walls, windows and doors (the cells a wall line connects through).
static func _walled(grid: WorldGrid, cell: Vector3i) -> bool:
	if not grid.in_bounds(cell):
		return false
	var terrain := grid.terrain_def_at(cell)
	return terrain.surface == "wall" or terrain.id == DOOR


static func _indoor(grid: WorldGrid, cell: Vector3i) -> bool:
	return grid.in_bounds(cell) and grid.terrain_def_at(cell).indoor


static func _is_door(grid: WorldGrid, cell: Vector3i) -> bool:
	return grid.in_bounds(cell) and grid.terrain_def_at(cell).id == DOOR


static func _near_indoor(grid: WorldGrid, cell: Vector3i) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			if (dx != 0 or dy != 0) and _indoor(grid, cell + Vector3i(dx, dy, 0)):
				return true
	return false
