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
	# The outer halves of the open building's thin walls show the street: darken those too.
	var half := px / 2
	for id: int in interiors.revealed:
		for cell: Vector3i in interiors.cells(id):
			var kind := WallShapes.kind(grid, cell)
			if kind != WallShapes.THIN and kind != WallShapes.DOORWAY:
				continue
			for q: int in 4:
				if not interiors.is_open(WallShapes.quadrant_ground(grid, cell, q)):
					draw_rect(Rect2(cell.x * px + (q % 2) * half, cell.y * px + (q / 2) * half, half, half), shade)
	# Beyond the town's edge too, so the camera never shows a lit border.
	var size := Vector2(grid.width, grid.height) * px
	var margin := 4096.0
	draw_rect(Rect2(-margin, -margin, size.x + 2 * margin, margin), shade)
	draw_rect(Rect2(-margin, size.y, size.x + 2 * margin, margin), shade)
	draw_rect(Rect2(-margin, 0, margin, size.y), shade)
	draw_rect(Rect2(size.x, 0, margin, size.y), shade)

