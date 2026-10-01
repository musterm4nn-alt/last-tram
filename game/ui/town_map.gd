class_name TownMap
extends CanvasLayer
## The full map (M): the whole viewed level with every place's name and the player's
## marker, under the district's name. Pauses while open; closing restores the speed it had
## before, like PauseMenu.

## Share of the window the map may fill.
const FILL: float = 0.9
## Room kept for the title and the closing hint, in pixels.
const CHROME_PX: float = 80.0

## True while the map is shown (the rest of the game ignores input then).
var is_open: bool = false

var _speed_before: int = 1
var _title: Label
var _view: MapView


func _init() -> void:
	layer = 14
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_view = MapView.new()
	_view.show_labels = true
	box.add_child(_view)
	var hint := Label.new()
	hint.text = "M or Esc to close"
	hint.add_theme_font_size_override("font_size", 13)
	hint.modulate = Color(1, 1, 1, 0.75)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	visible = false


## The largest whole number of pixels per cell at which a map of `map_cells` fits in
## `space` (at least 1).
static func fit_scale(map_cells: Vector2i, space: Vector2) -> int:
	if map_cells.x <= 0 or map_cells.y <= 0:
		return 1
	return maxi(1, floori(minf(space.x / map_cells.x, space.y / map_cells.y)))


## Pauses (remembers Session.speed, then speed 0) and shows the map.
func open() -> void:
	if is_open or Session.sim == null:
		return
	is_open = true
	_speed_before = Session.speed
	Session.set_speed(0)
	var grid := Session.sim.world.grid
	var window := Vector2(1280, 720)
	if is_inside_tree():
		window = get_viewport().get_visible_rect().size
	var space := window * FILL - Vector2(0, CHROME_PX)
	_view.px_per_cell = fit_scale(Vector2i(grid.width, grid.height), space)
	_view.custom_minimum_size = Vector2(grid.width, grid.height) * _view.px_per_cell
	var district_ids := Session.content.district_order
	_title.text = Session.content.districts[district_ids[0]].name if not district_ids.is_empty() else "Map"
	visible = true


## Hides the map and restores the speed it had before open().
func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Session.set_speed(_speed_before)
