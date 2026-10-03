class_name RoofsView2D
extends Node2D
## Builds Interiors.current and one RoofView2D per building (T-0086), and each frame opens
## the player's building and closes the rest. Lives in the y-sorted DepthLayer2D.

var _roofs: Array[RoofView2D] = []
var _built_revision: int = -1
var _key: Array = []


func _init() -> void:
	name = "Roofs"
	y_sort_enabled = true


func _ready() -> void:
	Session.game_loaded.connect(rebuild)


func rebuild() -> void:
	for roof: RoofView2D in _roofs:
		roof.queue_free()
	_roofs.clear()
	_key = []
	if Session.sim == null:
		Interiors.current = Interiors.new()
		return
	var grid := Session.sim.world.grid
	Interiors.current = Interiors.build(grid)
	_built_revision = grid.revision
	var placeholder := (PlaceholderTiles.build_tile_set(Session.content).get_source(PlaceholderTiles.SOURCE_ID) as TileSetAtlasSource).texture
	var roof_tiles := PlaceholderTiles.build_roof_texture()
	for id: int in Interiors.current.size():
		var roof := RoofView2D.new()
		roof.building_id = id
		roof.placeholder_tiles = placeholder
		roof.roof_tiles = roof_tiles
		roof.position = Vector2(0, Interiors.current.bottom(id))
		add_child(roof)
		_roofs.append(roof)


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	if Session.sim.world.grid.revision != _built_revision:
		rebuild()
	var player := Session.sim.world.player()
	var cell := player.cell() if player != null else Vector3i(-1, -1, -1000)
	var key: Array = [cell, Session.viewed_level]
	if key == _key:
		return
	_key = key
	var interiors := Interiors.current
	interiors.revealed = interiors.reveal_for(cell, Session.viewed_level)
	for roof: RoofView2D in _roofs:
		roof.visible = interiors.level(roof.building_id) == Session.viewed_level and not interiors.revealed.has(roof.building_id)
