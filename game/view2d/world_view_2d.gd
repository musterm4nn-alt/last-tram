class_name WorldView2D
extends Node2D
## Draws the world grid with placeholder tiles: one TileMapLayer per floor level, and only
## the level in Session.viewed_level is visible. Rebuilds when the grid changes.

var _layers: Dictionary[int, TileMapLayer] = {}
var _built_revision: int = -1


func _ready() -> void:
	Session.game_loaded.connect(rebuild)


func rebuild() -> void:
	for layer: TileMapLayer in _layers.values():
		layer.queue_free()
	_layers.clear()
	var grid := Session.sim.world.grid
	var tile_set := PlaceholderTiles.build_tile_set(Session.content)
	for level: int in grid.levels():
		var layer := TileMapLayer.new()
		layer.name = "Level%d" % level
		layer.tile_set = tile_set
		for y: int in grid.height:
			for x: int in grid.width:
				var terrain := grid.terrain_at(Vector3i(x, y, level))
				layer.set_cell(Vector2i(x, y), PlaceholderTiles.SOURCE_ID, Vector2i(terrain, 0))
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


func _update_visibility() -> void:
	for level: int in _layers:
		_layers[level].visible = level == Session.viewed_level
