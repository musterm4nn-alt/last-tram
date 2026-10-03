class_name PlaceholderTiles
extends RefCounted
## Generates a TileSet of simple coloured tiles from the terrain debug colours, so the game
## is playable before any art exists. Atlas coords (terrain_index, 0) = that terrain.
## Art sets (ArtSet) add their own atlas sources next to this one; cells they don't map keep
## these tiles.

const SOURCE_ID: int = 0


static func build_tile_set(content: ContentDB) -> TileSet:
	var px := ViewConfig.TILE_PX
	var image := Image.create_empty(px * content.terrains.size(), px, false, Image.FORMAT_RGBA8)
	for i: int in content.terrains.size():
		_paint(image, i * px, px, content.terrain(i), content)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(px, px)
	for i: int in content.terrains.size():
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(px, px)
	tile_set.add_source(source, SOURCE_ID)
	return tile_set


static func _paint(image: Image, x0: int, px: int, t: TerrainDef, content: ContentDB) -> void:
	var base := t.debug_color
	image.fill_rect(Rect2i(x0, 0, px, px), base)
	match t.id:
		"tree":
			var grass := content.terrain(content.terrain_index("grass")).debug_color
			image.fill_rect(Rect2i(x0, 0, px, px), grass)
			_disc(image, x0 + px / 2, px / 2, px / 2 - 1, base)
			_disc(image, x0 + px / 2 - 2, px / 2 - 2, px / 4, base.lightened(0.15))
			return
		"crossing":
			var road := content.terrain(content.terrain_index("road")).debug_color
			image.fill_rect(Rect2i(x0, 0, px, px), road)
			for x: int in range(0, px, 4):
				image.fill_rect(Rect2i(x0 + x, 0, 2, px), base)
			return
		"fountain":
			_disc(image, x0 + px / 2, px / 2, px / 3, base.lightened(0.3))
			return
		"stairs":
			for i: int in 3:
				image.fill_rect(Rect2i(x0, px * (i + 1) / 4 - 1, px, 2), base.darkened(0.3))
			return
	match t.surface:
		"wall":
			image.fill_rect(Rect2i(x0, 0, px, px / 4), base.lightened(0.18))
			image.fill_rect(Rect2i(x0, px - 1, px, 1), base.darkened(0.35))
		"rail":
			image.fill_rect(Rect2i(x0, px / 4, px, 2), base.lightened(0.45))
			image.fill_rect(Rect2i(x0, px - px / 4 - 2, px, 2), base.lightened(0.45))
		"water":
			image.fill_rect(Rect2i(x0 + 3, px / 3, 5, 1), base.lightened(0.25))
			image.fill_rect(Rect2i(x0 + 9, px * 2 / 3, 5, 1), base.lightened(0.25))
		"grass":
			for p: Vector2i in [Vector2i(3, 4), Vector2i(11, 2), Vector2i(7, 10), Vector2i(13, 13), Vector2i(2, 12)]:
				image.set_pixel(x0 + p.x * px / 16, p.y * px / 16, base.darkened(0.2))
		_:
			image.fill_rect(Rect2i(x0 + px - 1, 0, 1, px), base.darkened(0.12))
			image.fill_rect(Rect2i(x0, px - 1, px, 1), base.darkened(0.12))


static func _disc(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for y: int in range(cy - radius, cy + radius + 1):
		for x: int in range(cx - radius, cx + radius + 1):
			if Vector2(x - cx, y - cy).length() <= radius + 0.3:
				image.set_pixel(x, y, color)
