class_name InteriorDim2D
extends Node2D
## While the player is inside (in direct mode), darkens everything on the viewed floor outside
## the open building, so being indoors feels like a separate place (T-0086). Not lit by the night
## lights (light_mask 0); redraws only when the open building or the floor changes.

## How much of the street still shows through.
const SHOW: float = 0.18

var _key: Array = []


func _init() -> void:
	name = "InteriorDim"
	light_mask = 0


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var key: Array = [Interiors.current.revealed, Session.viewed_level, Session.sim.world.grid.revision, Session.command_mode]
	if key != _key:
		_key = key
		queue_redraw()


## The parts of quadrant `quadrant` (0 NW, 1 NE, 2 SW, 3 SE) of a thin wall or doorway cell
## that are ground, not wall (WallLayer2D: the band and its edge fill the middle 8 px, with
## arms to the walled neighbours in `arms`, and a 2-px face under east-west runs), in cell
## pixels, as 4-px blocks.
static func ground_rects(arms: int, quadrant: int) -> Array[Rect2i]:
	var block := ViewConfig.TILE_PX / 4
	var out: Array[Rect2i] = []
	for by: int in range((quadrant / 2) * 2, (quadrant / 2) * 2 + 2):
		for bx: int in range((quadrant % 2) * 2, (quadrant % 2) * 2 + 2):
			var mid_x := bx == 1 or bx == 2
			var mid_y := by == 1 or by == 2
			var band := (mid_x and mid_y) \
					or (mid_x and by == 0 and arms & WallShapes.ARM_N != 0) \
					or (mid_x and by == 3 and arms & WallShapes.ARM_S != 0) \
					or (mid_y and bx == 3 and arms & WallShapes.ARM_E != 0) \
					or (mid_y and bx == 0 and arms & WallShapes.ARM_W != 0)
			if band:
				continue
			if by == 3 and _under_face(arms, bx):
				# The narrow face under an east-west run (2 px) belongs to the wall too.
				out.append(Rect2i(bx * block, by * block + 2, block, block - 2))
			else:
				out.append(Rect2i(bx * block, by * block, block, block))
	return out


## True when WallLayer2D draws the narrow face (the 2 px below the band) over column block `bx`.
static func _under_face(arms: int, bx: int) -> bool:
	var west := arms & WallShapes.ARM_W != 0
	var east := arms & WallShapes.ARM_E != 0
	if arms & WallShapes.ARM_S != 0:
		return (bx == 0 and west) or (bx == 3 and east)
	return (bx == 1 or bx == 2) or (bx == 0 and west) or (bx == 3 and east)


func _draw() -> void:
	var interiors := Interiors.current
	if Session.sim == null or not interiors.shuts_out_street(Session.command_mode):
		return
	var grid := Session.sim.world.grid
	var px := ViewConfig.TILE_PX
	var shade := Color(0, 0, 0, 1.0 - SHOW)
	for y: int in grid.height:
		var run_start := -1
		for x: int in grid.width + 1:
			var dark := x < grid.width and not interiors.is_open(Vector3i(x, y, Session.viewed_level))
			if dark and run_start < 0:
				run_start = x
			elif not dark and run_start >= 0:
				draw_rect(Rect2(run_start * px, y * px, (x - run_start) * px, px), shade)
				run_start = -1
	# The outer halves of the open building's thin walls show the street: darken that ground,
	# but not the wall band itself, so outer walls show at full thickness (T-0090).
	for id: int in interiors.revealed:
		for cell: Vector3i in interiors.cells(id):
			var kind := WallShapes.kind(grid, cell)
			var trim := WallShapes.face_trim(grid, cell)
			# A corner's trimmed strip shows the street too (T-0089).
			if trim & WallShapes.ARM_W and not interiors.is_open(cell + Vector3i(-1, 0, 0)):
				draw_rect(Rect2(cell.x * px, cell.y * px, WallLayer2D.BAND_FROM - 1, px), shade)
			if trim & WallShapes.ARM_E and not interiors.is_open(cell + Vector3i(1, 0, 0)):
				var from := WallLayer2D.BAND_FROM + WallLayer2D.BAND + 1
				draw_rect(Rect2(cell.x * px + from, cell.y * px, px - from, px), shade)
			if kind != WallShapes.THIN and kind != WallShapes.DOORWAY:
				continue
			var arms := WallShapes.arms(grid, cell)
			for q: int in 4:
				if not interiors.is_open(WallShapes.quadrant_ground(grid, cell, q)):
					for rect: Rect2i in ground_rects(arms, q):
						draw_rect(Rect2(Vector2(cell.x * px, cell.y * px) + Vector2(rect.position), Vector2(rect.size)), shade)
	# Beyond the town's edge too, so the camera never shows a lit border.
	var size := Vector2(grid.width, grid.height) * px
	var margin := 4096.0
	draw_rect(Rect2(-margin, -margin, size.x + 2 * margin, margin), shade)
	draw_rect(Rect2(-margin, size.y, size.x + 2 * margin, margin), shade)
	draw_rect(Rect2(-margin, 0, margin, size.y), shade)
	draw_rect(Rect2(size.x, 0, margin, size.y), shade)

