class_name WallLayer2D
extends Node2D
## Draws one floor's thin walls and doorways (WallShapes.THIN / DOORWAY, T-0085) above that
## floor's TileMapLayer: the ground beside the wall in four quadrants, then a 6-px wall band
## through the middle of the cell with arms to the neighbouring walls, a narrow face under
## horizontal runs, glass in windows, jambs and a threshold in doorways. WorldView2D builds it
## with add_cell() and the colours; it only redraws when rebuilt.

const BAND_FROM: int = 5
const BAND: int = 6

## Colours: "top", "edge", "face", "glass", "door".
var colors: Dictionary = {}
var _cells: Array[Dictionary] = []


## The colours for walls whose base (average) colour is `base`.
static func colors_for(base: Color, door: Color) -> Dictionary:
	return {
		"top": base.lightened(0.18),
		"edge": base.darkened(0.5),
		"face": base.darkened(0.18),
		"glass": Color("#8fb8c9"),
		"door": door,
	}


## True when a wall with these arms runs east-west (for the glass of a window): it has both
## east and west arms, or east or west but neither north nor south. At a T-junction the
## straight run wins.
static func runs_across(arms: int) -> bool:
	var across := (arms & WallShapes.ARM_E != 0) and (arms & WallShapes.ARM_W != 0)
	var down := (arms & WallShapes.ARM_N != 0) and (arms & WallShapes.ARM_S != 0)
	if across != down:
		return across
	return arms & (WallShapes.ARM_N | WallShapes.ARM_S) == 0


## Adds a cell to draw. `quads` holds four {"texture", "region"} grounds (NW, NE, SW, SE),
## each possibly empty.
func add_cell(cell: Vector2i, kind: int, arms: int, window: bool, quads: Array[Dictionary]) -> void:
	_cells.append({"cell": cell, "kind": kind, "arms": arms, "window": window, "quads": quads})
	queue_redraw()


func _draw() -> void:
	var px := ViewConfig.TILE_PX
	var half := px / 2
	for entry: Dictionary in _cells:
		var origin: Vector2 = Vector2(entry["cell"]) * px
		var quads: Array[Dictionary] = entry["quads"]
		for q: int in 4:
			var ground: Dictionary = quads[q]
			if ground.is_empty():
				continue
			var offset := Vector2i((q % 2) * half, (q / 2) * half)
			var region: Rect2i = ground["region"]
			draw_texture_rect_region(ground["texture"], Rect2(origin + Vector2(offset), Vector2(half, half)),
					Rect2(Vector2(region.position + offset), Vector2(half, half)))
		if int(entry["kind"]) == WallShapes.DOORWAY:
			_draw_doorway(origin, int(entry["arms"]))
		else:
			_draw_band(origin, int(entry["arms"]), bool(entry["window"]))


## The wall band: the edge colour one pixel wider, the top inside it, then the face strip.
func _draw_band(origin: Vector2, arms: int, window: bool) -> void:
	var px := ViewConfig.TILE_PX
	var a := BAND_FROM
	var b := BAND_FROM + BAND
	var edge: Color = colors["edge"]
	var top: Color = colors["top"]
	_rect(origin, Rect2i(a - 1, a - 1, BAND + 2, BAND + 2), edge)
	if arms & WallShapes.ARM_N:
		_rect(origin, Rect2i(a - 1, 0, BAND + 2, a), edge)
	if arms & WallShapes.ARM_S:
		_rect(origin, Rect2i(a - 1, b, BAND + 2, px - b), edge)
	if arms & WallShapes.ARM_E:
		_rect(origin, Rect2i(b, a - 1, px - b, BAND + 2), edge)
	if arms & WallShapes.ARM_W:
		_rect(origin, Rect2i(0, a - 1, a, BAND + 2), edge)
	_rect(origin, Rect2i(a, a, BAND, BAND), top)
	if arms & WallShapes.ARM_N:
		_rect(origin, Rect2i(a, 0, BAND, a + 1), top)
	if arms & WallShapes.ARM_S:
		_rect(origin, Rect2i(a, b - 1, BAND, px - b + 1), top)
	if arms & WallShapes.ARM_E:
		_rect(origin, Rect2i(b - 1, a, px - b + 1, BAND), top)
	if arms & WallShapes.ARM_W:
		_rect(origin, Rect2i(0, a, a + 1, BAND), top)
	# The narrow face under horizontal runs (the wall's height, seen from the south).
	var face: Color = colors["face"]
	var from_x := 0 if arms & WallShapes.ARM_W else a - 1
	var to_x := px if arms & WallShapes.ARM_E else b + 1
	if arms & WallShapes.ARM_S:
		if arms & WallShapes.ARM_W:
			_rect(origin, Rect2i(0, b + 1, a - 1, 2), face)
		if arms & WallShapes.ARM_E:
			_rect(origin, Rect2i(b + 1, b + 1, px - b - 1, 2), face)
	else:
		_rect(origin, Rect2i(from_x, b + 1, to_x - from_x, 2), face)
	if window:
		var glass: Color = colors["glass"]
		if runs_across(arms):
			_rect(origin, Rect2i(1, a + 2, px - 2, 2), glass)
		else:
			_rect(origin, Rect2i(a + 2, 1, 2, px - 2), glass)


## A doorway: jambs where the wall meets it, and a wooden threshold across.
func _draw_doorway(origin: Vector2, arms: int) -> void:
	var px := ViewConfig.TILE_PX
	var a := BAND_FROM
	var edge: Color = colors["edge"]
	var top: Color = colors["top"]
	var door: Color = colors["door"]
	if arms & (WallShapes.ARM_E | WallShapes.ARM_W) or arms == 0:
		_rect(origin, Rect2i(3, a + 2, px - 6, 2), door)
		for x: int in [0, px - 3]:
			_rect(origin, Rect2i(x, a - 1, 3, BAND + 2), edge)
			_rect(origin, Rect2i(x + (0 if x == 0 else 1), a, 2, BAND), top)
	else:
		_rect(origin, Rect2i(a + 2, 3, 2, px - 6), door)
		for y: int in [0, px - 3]:
			_rect(origin, Rect2i(a - 1, y, BAND + 2, 3), edge)
			_rect(origin, Rect2i(a, y + (0 if y == 0 else 1), BAND, 2), top)


func _rect(origin: Vector2, rect: Rect2i, color: Color) -> void:
	draw_rect(Rect2(origin + Vector2(rect.position), Vector2(rect.size)), color)
