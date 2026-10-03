class_name NightLights2D
extends Node2D
## Tints the world by the clock (a CanvasModulate) and, from dusk to dawn, lights it with one
## white PointLight2D whose texture is DayNight.light_map (the colours are in the map):
## sodium-orange pools under the street lamps, glowing windows and lit interiors. The HUD and other CanvasLayers stay untinted.
## The map is rebuilt only when it can change: another floor, a new grid, a new game, or a
## new share of lit windows.

## Tag of the objects that light the street.
const LAMP_TAG: String = "street_lamp"

var _tint: CanvasModulate
var _light: PointLight2D
## What the current map was built from (level, grid revision, window share, game).
var _built_key: Array = []
var _game: int = 0


func _init() -> void:
	name = "NightLights"
	_tint = CanvasModulate.new()
	add_child(_tint)
	_light = PointLight2D.new()
	_light.blend_mode = Light2D.BLEND_MODE_ADD
	_light.texture_scale = float(ViewConfig.TILE_PX) / DayNight.LIGHT_PX
	_light.visible = false
	add_child(_light)


func _ready() -> void:
	Session.game_loaded.connect(func() -> void: _game += 1)


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var minute := Session.sim.clock.minute_of_day()
	_tint.color = DayNight.tint(minute)
	var dark := DayNight.darkness(minute)
	_light.visible = dark > 0.0
	_light.energy = dark
	if not _light.visible:
		return
	var grid := Session.sim.world.grid
	var key: Array = [Session.viewed_level, grid.revision, DayNight.window_share(minute), _game]
	if key != _built_key:
		_built_key = key
		var image := DayNight.light_map(grid, Session.viewed_level, lamp_cells(Session.sim.world, Session.viewed_level), minute)
		_light.texture = ImageTexture.create_from_image(image)
		_light.position = Vector2(grid.width, grid.height) * ViewConfig.TILE_PX / 2.0


## Cells of the street lamps on one floor.
static func lamp_cells(world: World, level: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for id: int in world.objects_tagged(LAMP_TAG):
		var origin: Vector3i = world.objects[id].origin
		if origin.z == level:
			out.append(Vector2i(origin.x, origin.y))
	return out
