extends TestCase
## T-0085: walls are drawn by direction: the top wall of a room shows its face, the others
## are thin lines with the right arms and the right ground beside them.

## A room with a window in its top wall and one in its west wall, a door in the top wall, a
## door in the east wall, a doorway in the bottom wall; a free-standing wall on the square.
const ROWS: PackedStringArray = [
	"::::::::::",
	":#W#D##:::",
	":W.....D::",
	":#..@..#::",
	":###D###::",
	"::::::::::",
	"::::##::::",
	"::::::::::",
]


func _grid() -> WorldGrid:
	return SimFactory.from_rows(content(), ROWS).world.grid


func test_kinds_in_a_room() -> void:
	var grid := _grid()
	assert_eq(WallShapes.kind(grid, Vector3i(3, 1, 0)), WallShapes.FACE, "top wall")
	assert_eq(WallShapes.kind(grid, Vector3i(2, 1, 0)), WallShapes.FACE, "window in the top wall")
	assert_eq(WallShapes.kind(grid, Vector3i(1, 1, 0)), WallShapes.FACE, "top-left corner carries the top wall's face")
	assert_eq(WallShapes.kind(grid, Vector3i(1, 4, 0)), WallShapes.THIN, "bottom-left corner stays thin")
	assert_eq(WallShapes.kind(grid, Vector3i(1, 2, 0)), WallShapes.THIN, "window in the west wall")
	assert_eq(WallShapes.kind(grid, Vector3i(7, 3, 0)), WallShapes.THIN, "east wall")
	assert_eq(WallShapes.kind(grid, Vector3i(2, 4, 0)), WallShapes.THIN, "bottom wall")
	assert_eq(WallShapes.kind(grid, Vector3i(4, 6, 0)), WallShapes.FACE, "free-standing wall")
	assert_eq(WallShapes.kind(grid, Vector3i(3, 3, 0)), WallShapes.NONE, "floor")
	assert_eq(WallShapes.kind(grid, Vector3i(0, 0, 0)), WallShapes.NONE, "square")
	assert_eq(WallShapes.kind(grid, Vector3i(-1, 0, 0)), WallShapes.NONE, "outside the town")


func test_door_kinds() -> void:
	var grid := _grid()
	assert_eq(WallShapes.kind(grid, Vector3i(4, 1, 0)), WallShapes.FACE, "front door in the top wall")
	assert_eq(WallShapes.kind(grid, Vector3i(7, 2, 0)), WallShapes.DOORWAY, "door in the east wall")
	assert_eq(WallShapes.kind(grid, Vector3i(4, 4, 0)), WallShapes.DOORWAY, "door in the bottom wall")


func test_arms() -> void:
	var grid := _grid()
	assert_eq(WallShapes.arms(grid, Vector3i(1, 1, 0)), WallShapes.ARM_E | WallShapes.ARM_S, "corner")
	assert_eq(WallShapes.arms(grid, Vector3i(1, 3, 0)), WallShapes.ARM_N | WallShapes.ARM_S, "west wall")
	assert_eq(WallShapes.arms(grid, Vector3i(7, 3, 0)), WallShapes.ARM_N | WallShapes.ARM_S, "east wall, door above")
	assert_eq(WallShapes.arms(grid, Vector3i(4, 4, 0)), WallShapes.ARM_E | WallShapes.ARM_W, "doorway in the bottom wall")
	assert_eq(WallShapes.arms(grid, Vector3i(4, 6, 0)), WallShapes.ARM_E, "free wall, one neighbour")


func test_quadrant_ground() -> void:
	var grid := _grid()
	var west_wall := Vector3i(1, 3, 0)
	assert_eq(WallShapes.quadrant_ground(grid, west_wall, 0), Vector3i(0, 3, 0), "NW: the square to the west")
	assert_eq(WallShapes.quadrant_ground(grid, west_wall, 3), Vector3i(2, 3, 0), "SE: the floor to the east")
	var bottom := Vector3i(2, 4, 0)
	assert_eq(WallShapes.quadrant_ground(grid, bottom, 0), Vector3i(2, 3, 0), "NW: the floor above")
	assert_eq(WallShapes.quadrant_ground(grid, bottom, 2), Vector3i(2, 5, 0), "SW: the square below")
	var corner := Vector3i(1, 1, 0)
	assert_eq(WallShapes.quadrant_ground(grid, corner, 3), Vector3i(2, 2, 0), "SE of a corner: the diagonal floor")
	assert_eq(WallShapes.quadrant_ground(grid, corner, 0), Vector3i(0, 1, 0), "NW of a corner: the square")


func test_glass_follows_the_straight_run() -> void:
	assert_false(WallLayer2D.runs_across(WallShapes.ARM_N | WallShapes.ARM_S | WallShapes.ARM_E), "T-junction on a north-south wall")
	assert_true(WallLayer2D.runs_across(WallShapes.ARM_E | WallShapes.ARM_W | WallShapes.ARM_S), "T-junction on an east-west wall")
	assert_true(WallLayer2D.runs_across(WallShapes.ARM_E), "end of an east-west wall")
	assert_false(WallLayer2D.runs_across(WallShapes.ARM_S), "end of a north-south wall")
	assert_true(WallLayer2D.runs_across(0), "alone: east-west")


## T-0089: a corner's face is trimmed back to the thin wall below it on its open side only.
func test_face_trim_at_corners() -> void:
	var grid := _grid()
	assert_eq(WallShapes.face_trim(grid, Vector3i(1, 1, 0)), WallShapes.ARM_W, "top-left corner: the square side")
	assert_eq(WallShapes.face_trim(grid, Vector3i(3, 1, 0)), 0, "top wall over the room")
	assert_eq(WallShapes.face_trim(grid, Vector3i(4, 6, 0)), 0, "free-standing wall")
	assert_eq(WallShapes.face_trim(grid, Vector3i(1, 3, 0)), 0, "a thin wall is never trimmed")
	var flat := SimFactory.from_rows(content(), PackedStringArray([
		":::::::",
		":#####:",
		":#...#:",
		":##.###",
		":#....:",
		":#####:",
	])).world.grid
	assert_eq(WallShapes.face_trim(flat, Vector3i(5, 1, 0)), WallShapes.ARM_E, "top-right corner")
	assert_eq(WallShapes.face_trim(flat, Vector3i(1, 3, 0)), WallShapes.ARM_W, "junction with the west wall")
	assert_eq(WallShapes.face_trim(flat, Vector3i(5, 3, 0)), 0, "a wall continues to the east")
