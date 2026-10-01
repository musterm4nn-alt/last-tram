class_name MapView
extends Control
## A top-down map of the viewed level: one texture pixel per cell in the terrain debug
## colours, scaled by px_per_cell, with a marker where the player is. The minimap follows
## the player; the town map (TownMap) shows the whole level with place names.

## Smallest marker radius; on big maps it grows to half a cell.
const MARKER_RADIUS_PX: float = 4.0
const MARKER_OUTLINE: Color = Color("#141414")
const LABEL_FONT_SIZE: int = 13
const LABEL_OUTLINE_PX: int = 4

## Screen pixels per cell.
var px_per_cell: float = 4.0
## Centre on the player (clamped to the map's edges) instead of showing from the top left.
var follow: bool = false
## Draw place names at the centre of each place.
var show_labels: bool = false

var _texture: ImageTexture
var _built_revision: int = -1
var _built_level: int = 0
var _built_sim: Sim


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The level as an image: one pixel per cell, coloured by terrain debug_color.
static func map_image(grid: WorldGrid, content: ContentDB, level: int) -> Image:
	var image := Image.create_empty(maxi(grid.width, 1), maxi(grid.height, 1), false, Image.FORMAT_RGBA8)
	for y: int in grid.height:
		for x: int in grid.width:
			image.set_pixel(x, y, grid.terrain_def_at(Vector3i(x, y, level)).debug_color)
	return image


## The cells to show: `view_cells` wide and high, centred on `center` but kept inside a map
## of `map_cells`. On an axis where the map is smaller than the view, the map is centred.
static func view_rect(map_cells: Vector2, center: Vector2, view_cells: Vector2) -> Rect2:
	var top_left := Vector2.ZERO
	for axis: int in 2:
		if map_cells[axis] <= view_cells[axis]:
			top_left[axis] = (map_cells[axis] - view_cells[axis]) / 2.0
		else:
			top_left[axis] = clampf(center[axis] - view_cells[axis] / 2.0, 0.0, map_cells[axis] - view_cells[axis])
	return Rect2(top_left, view_cells)


## Place names for `level`: [{"name": String, "cell": Vector2}], "cell" being the centre of
## the place's rect in cells, in district and authoring order.
static func labels(content: ContentDB, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for district_id: String in content.district_order:
		for place: PlaceDef in content.districts[district_id].places:
			if place.level == level:
				out.append({"name": place.name, "cell": Vector2(place.rect.position) + Vector2(place.rect.size) / 2.0})
	return out


func _process(_delta: float) -> void:
	if Session.sim == null or not is_visible_in_tree():
		return
	var grid := Session.sim.world.grid
	if _built_sim != Session.sim or grid.revision != _built_revision or Session.viewed_level != _built_level:
		_built_sim = Session.sim
		_built_revision = grid.revision
		_built_level = Session.viewed_level
		_texture = ImageTexture.create_from_image(map_image(grid, Session.content, _built_level))
	queue_redraw()


func _draw() -> void:
	if _texture == null or Session.sim == null:
		return
	var map_cells := Vector2(_texture.get_size())
	var player := Session.sim.world.player()
	var center := player.pos if player != null else map_cells / 2.0
	var shown := view_rect(map_cells, center, size / px_per_cell) if follow else Rect2(Vector2.ZERO, map_cells)
	draw_texture_rect(_texture, Rect2(-shown.position * px_per_cell, map_cells * px_per_cell), false)
	if show_labels:
		var font := get_theme_default_font()
		for label: Dictionary in labels(Session.content, _built_level):
			var text: String = label["name"]
			var cell: Vector2 = label["cell"]
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE).x
			var at := (cell - shown.position) * px_per_cell + Vector2(-width / 2.0, LABEL_FONT_SIZE / 2.0)
			# Keep names near the edge readable instead of clipped.
			at.x = clampf(at.x, LABEL_OUTLINE_PX, maxf(LABEL_OUTLINE_PX, size.x - width - LABEL_OUTLINE_PX))
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_OUTLINE_PX, MARKER_OUTLINE)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
	if player != null and player.level == _built_level:
		var spot := (player.pos - shown.position) * px_per_cell
		var radius := maxf(MARKER_RADIUS_PX, px_per_cell * 0.5)
		draw_circle(spot, radius + 1.5, MARKER_OUTLINE)
		draw_circle(spot, radius, ViewConfig.PLAYER_MARKER_COLOR)
