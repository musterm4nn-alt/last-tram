class_name SourceTiles2D
extends RefCounted
## Adapts generated source regions to cached, nearest-neighbour 16-pixel tiles in memory.
## Source PNGs stay intact. Optional backgrounds compose existing generated art under alpha.


## A tile entry for ArtSet, or {} with contextual errors for invalid input.
static func read(data: Dictionary, sheets: Dictionary[String, Texture2D], reader: ContentReader, ctx: String) -> Dictionary:
	var before := reader.errors.size()
	var sheet := reader.read_str(data, "sheet", ctx)
	var texture: Texture2D = sheets.get(sheet)
	if texture == null:
		reader.error("%s: no loaded sheet '%s'" % [ctx, sheet])
		return {}
	var values := reader.read_arr(data, "source_rects", ctx)
	if values.is_empty():
		reader.error("%s: source_rects must not be empty" % ctx)
		return {}
	var pattern := Vector2i.ONE
	var origin := Vector2i.ZERO
	if data.has("pattern"):
		pattern = _coordinates(data, "pattern", reader, ctx)
	if data.has("pattern_origin"):
		origin = _coordinates(data, "pattern_origin", reader, ctx)
	if pattern.x < 1 or pattern.y < 1 or pattern.x > 8 or pattern.y > 8:
		reader.error("%s: pattern must be between 1x1 and 8x8 cells" % ctx)
	var regions: Array[Rect2i] = []
	for value: Variant in values:
		regions.append(_region({"rect": value}, texture, reader, ctx))
	var background: Image
	if data.has("background"):
		var d := reader.read_obj(data, "background", ctx)
		var bg_sheet := reader.read_str(d, "sheet", ctx + ": background")
		var bg_texture: Texture2D = sheets.get(bg_sheet)
		if bg_texture == null:
			reader.error("%s: background sheet '%s' is not loaded" % [ctx, bg_sheet])
		else:
			var bg_region := _region(d, bg_texture, reader, ctx + ": background")
			if reader.errors.size() == before:
				background = bg_texture.get_image().get_region(bg_region)
				background.convert(Image.FORMAT_RGBA8)
				background.resize(ViewConfig.TILE_PX, ViewConfig.TILE_PX, Image.INTERPOLATE_NEAREST)
	if reader.errors.size() != before:
		return {}
	var size := pattern * ViewConfig.TILE_PX
	var atlas := Image.create_empty(size.x * regions.size(), size.y, false, Image.FORMAT_RGBA8)
	var source := texture.get_image()
	for i: int in regions.size():
		var dest := Vector2i(i * size.x, 0)
		if background != null:
			for y: int in pattern.y:
				for x: int in pattern.x:
					atlas.blend_rect(background, Rect2i(Vector2i.ZERO, background.get_size()), dest + Vector2i(x, y) * ViewConfig.TILE_PX)
		var image := source.get_region(regions[i])
		image.convert(Image.FORMAT_RGBA8)
		image.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
		atlas.blend_rect(image, Rect2i(Vector2i.ZERO, size), dest)
	return {"texture": ImageTexture.create_from_image(atlas), "cell": Vector2i.ZERO,
			"variants": regions.size(), "pattern": pattern, "pattern_origin": origin}


static func _coordinates(data: Dictionary, key: String, reader: ContentReader, ctx: String) -> Vector2i:
	var values := reader.read_coordinates(data, key, ctx, 2)
	return Vector2i(values[0], values[1]) if values.size() == 2 else Vector2i.ZERO


static func _region(data: Dictionary, texture: Texture2D, reader: ContentReader, ctx: String) -> Rect2i:
	var values := reader.read_coordinates(data, "rect", ctx, 4)
	if values.is_empty():
		return Rect2i()
	var region := Rect2i(values[0], values[1], values[2], values[3])
	if region.size.x < 1 or region.size.y < 1 or not Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(region):
		reader.error("%s: source rect %s is outside the sheet or empty" % [ctx, values])
	return region
