class_name WorldView2D
extends Node2D
## Draws the world grid: one TileMapLayer per floor level, and only the level in
## Session.viewed_level is visible. Each cell uses the active art set's tile for its terrain,
## or the placeholder tile when the set has none. Rebuilds when the grid changes.

## The art set the 2D view draws with (set from --art in main.gd). Empty = placeholders.
static var art: ArtSet = ArtSet.new()

var _layers: Dictionary[int, TileMapLayer] = {}
var _built_revision: int = -1
## Atlas source id per art sheet texture, in the tile set being built.
var _sources: Dictionary[Texture2D, int] = {}


func _ready() -> void:
	Session.game_loaded.connect(rebuild)


func rebuild() -> void:
	for layer: TileMapLayer in _layers.values():
		layer.queue_free()
	_layers.clear()
	_sources.clear()
	var grid := Session.sim.world.grid
	var tile_set := PlaceholderTiles.build_tile_set(Session.content)
	for level: int in grid.levels():
		var layer := TileMapLayer.new()
		layer.name = "Level%d" % level
		layer.tile_set = tile_set
		for y: int in grid.height:
			for x: int in grid.width:
				var terrain := grid.terrain_at(Vector3i(x, y, level))
				var tile := art.terrain_tile(Session.content.terrain(terrain).id, Vector2i(x, y))
				if tile.is_empty():
					layer.set_cell(Vector2i(x, y), PlaceholderTiles.SOURCE_ID, Vector2i(terrain, 0))
				else:
					var region: Rect2i = tile["region"]
					var coords := region.position / ViewConfig.TILE_PX
					layer.set_cell(Vector2i(x, y), _source_for(tile_set, tile["texture"], coords), coords)
		add_child(layer)
		_layers[level] = layer
	_built_revision = grid.revision
	_update_visibility()


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	if Session.sim.world.grid.revision != _built_revision:
		rebuild()
	_update_visibility()


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
