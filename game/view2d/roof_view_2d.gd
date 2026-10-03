class_name RoofView2D
extends Node2D
## One closed building seen from outside (T-0086): its front (the walls, windows and doors
## whose south side is outside) drawn as faces, its entrances as doors, and a roof over the
## rest, with a dark eave along the roof's lower edge. The node sits at the building's lowest
## edge, so in the y-sorted depth layer a person or lamp south of it draws in front.
## RoofsView2D shows it only while the building is closed and on the viewed floor.

const EAVE_COLOR: Color = Color(0, 0, 0, 0.35)

var building_id: int = 0
## Ground tiles (from WorldView2D's art set or the placeholders) and the roof strip.
var placeholder_tiles: Texture2D
var roof_tiles: Texture2D


func _draw() -> void:
	var interiors := Interiors.current
	if Session.sim == null or building_id >= interiors.size():
		return
	draw_set_transform(-position)
	var grid := Session.sim.world.grid
	var px := ViewConfig.TILE_PX
	var roof_index := building_id % PlaceholderTiles.ROOF_COLORS.size()
	for cell: Vector3i in interiors.cells(building_id):
		var at := Rect2(Vector2(cell.x, cell.y) * px, Vector2(px, px))
		if interiors.is_front(grid, cell) or interiors.is_entrance(grid, cell):
			_draw_tile(at, _terrain_tile(grid, cell))
			continue
		var tile := WorldView2D.art.roof_tile(Vector2i(cell.x, cell.y))
		if tile.is_empty():
			tile = {"texture": roof_tiles, "region": Rect2i(roof_index * px, 0, px, px)}
		_draw_tile(at, tile)
		var south := cell + Vector3i(0, 1, 0)
		if not interiors.buildings_at(south).has(building_id) or interiors.is_front(grid, south):
			draw_rect(Rect2(at.position + Vector2(0, px - 2), Vector2(px, 2)), EAVE_COLOR)


func _terrain_tile(grid: WorldGrid, cell: Vector3i) -> Dictionary:
	var terrain := grid.terrain_at(cell)
	var tile := WorldView2D.art.terrain_tile(Session.content.terrain(terrain).id, Vector2i(cell.x, cell.y))
	if tile.is_empty():
		var px := ViewConfig.TILE_PX
		tile = {"texture": placeholder_tiles, "region": Rect2i(terrain * px, 0, px, px)}
	return tile


func _draw_tile(at: Rect2, tile: Dictionary) -> void:
	draw_texture_rect_region(tile["texture"], at, Rect2(tile["region"]))
