class_name WorldView2D
extends Node2D
## Draws the world grid: one TileMapLayer per floor level, and only the level in
## Session.viewed_level is visible. Each cell uses the active art set's tile for its terrain,
## or the placeholder tile when the set has none. Thin walls and doorways (WallShapes, T-0085)
## are left out of the tile layer and drawn by a WallLayer2D per floor. Rebuilds when the
## grid changes.

## The art set the 2D view draws with (set from --art in main.gd). Empty = placeholders.
static var art: ArtSet = ArtSet.new()

var _layers: Dictionary[int, TileMapLayer] = {}
var _wall_layers: Dictionary[int, WallLayer2D] = {}
var _built_revision: int = -1
## Atlas source id per art sheet texture, in the tile set being built.
var _sources: Dictionary[Texture2D, int] = {}


func _ready() -> void:
	Session.game_loaded.connect(rebuild)


func rebuild() -> void:
	for layer: TileMapLayer in _layers.values():
		layer.queue_free()
	for walls: WallLayer2D in _wall_layers.values():
		walls.queue_free()
	_layers.clear()
	_wall_layers.clear()
	_sources.clear()
	var grid := Session.sim.world.grid
	var tile_set := PlaceholderTiles.build_tile_set(Session.content)
	var placeholder := (tile_set.get_source(PlaceholderTiles.SOURCE_ID) as TileSetAtlasSource).texture
	var colors := _wall_colors(placeholder)
	for level: int in grid.levels():
		var layer := TileMapLayer.new()
		layer.name = "Level%d" % level
		layer.tile_set = tile_set
		var walls := WallLayer2D.new()
		walls.name = "Walls%d" % level
		walls.colors = colors
		for y: int in grid.height:
			for x: int in grid.width:
				var cell := Vector3i(x, y, level)
				var kind := WallShapes.kind(grid, cell)
				if kind == WallShapes.THIN or kind == WallShapes.DOORWAY:
					var quads: Array[Dictionary] = []
					for q: int in 4:
						quads.append(_ground(grid, WallShapes.quadrant_ground(grid, cell, q), placeholder))
					walls.add_cell(Vector2i(x, y), kind, WallShapes.arms(grid, cell), grid.terrain_def_at(cell).id == "window", quads)
					continue
				var terrain := grid.terrain_at(cell)
				var tile := art.terrain_tile(Session.content.terrain(terrain).id, Vector2i(x, y))
				if tile.is_empty():
					layer.set_cell(Vector2i(x, y), PlaceholderTiles.SOURCE_ID, Vector2i(terrain, 0))
				else:
					var region: Rect2i = tile["region"]
					var coords := region.position / ViewConfig.TILE_PX
					layer.set_cell(Vector2i(x, y), _source_for(tile_set, tile["texture"], coords), coords)
		add_child(layer)
		add_child(walls)
		_layers[level] = layer
		_wall_layers[level] = walls
	_built_revision = grid.revision
	_update_visibility()


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	if Session.sim.world.grid.revision != _built_revision:
		rebuild()
	_update_visibility()


## The tile drawn for a cell's ground: {"texture", "region"} from the art set or the
## placeholder; {} for walls (a thin wall with walls all round).
func _ground(grid: WorldGrid, cell: Vector3i, placeholder: Texture2D) -> Dictionary:
	var terrain := grid.terrain_at(cell)
	var terrain_id := Session.content.terrain(terrain).id
	if WallShapes.kind(grid, cell) != WallShapes.NONE:
		return {}
	var tile := art.terrain_tile(terrain_id, Vector2i(cell.x, cell.y))
	if not tile.is_empty():
		return tile
	var px := ViewConfig.TILE_PX
	return {"texture": placeholder, "region": Rect2i(terrain * px, 0, px, px)}


## Thin wall colours: the art set's "thin_walls", else from the wall tile's average colour.
func _wall_colors(placeholder: Texture2D) -> Dictionary:
	var door_color := Session.content.terrain(Session.content.terrain_index("door")).debug_color
	var colors := WallLayer2D.colors_for(_average("wall", placeholder), door_color)
	for key: String in art.thin_walls:
		colors[key] = art.thin_walls[key]
	return colors


## The average opaque colour of a terrain's tile (first variant).
func _average(terrain_id: String, placeholder: Texture2D) -> Color:
	var tile := art.terrain_tile(terrain_id, Vector2i.ZERO)
	var index := Session.content.terrain_index(terrain_id)
	if tile.is_empty():
		return Session.content.terrain(index).debug_color
	var image: Image = (tile["texture"] as Texture2D).get_image()
	var region: Rect2i = tile["region"]
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var c := image.get_pixel(x, y)
			if c.a > 0.5:
				sum += c
				n += 1
	return Color(sum.r / n, sum.g / n, sum.b / n) if n > 0 else Session.content.terrain(index).debug_color


## The atlas source for an art sheet (added on first use), with a tile at `coords`.
func _source_for(tile_set: TileSet, texture: Texture2D, coords: Vector2i) -> int:
	if not _sources.has(texture):
		var source := TileSetAtlasSource.new()
		source.texture = texture
		source.texture_region_size = Vector2i(ViewConfig.TILE_PX, ViewConfig.TILE_PX)
		_sources[texture] = tile_set.add_source(source)
	var source_id := _sources[texture]
	var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
	if not atlas.has_tile(coords):
		atlas.create_tile(coords)
	return source_id


func _update_visibility() -> void:
	for level: int in _layers:
		_layers[level].visible = level == Session.viewed_level
		_wall_layers[level].visible = level == Session.viewed_level
