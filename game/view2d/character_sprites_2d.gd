class_name CharacterSprites2D
extends RefCounted
## Validated four-direction sprite frames for an optional art-set character trial.
## Canned designs are view-only; appearance, outfits and saves remain simulation data.

var _characters: Dictionary[String, Dictionary] = {}
var _npcs: Array[String] = []


## Reads optional characters from an art set. Bad entries fall back to PersonDrawer2D.
func read(data: Dictionary, sheets: Dictionary[String, Texture2D], reader: ContentReader, path: String) -> void:
	for key: Variant in data:
		var ctx := "%s: character '%s'" % [path, key]
		var before := reader.errors.size()
		var d := reader.read_obj(data, str(key), ctx)
		var sheet := reader.read_str(d, "sheet", ctx)
		var texture: Texture2D = sheets.get(sheet)
		if texture == null:
			reader.error("%s: no loaded sheet '%s'" % [ctx, sheet])
		var fps := reader.read_num(d, "fps", ctx)
		if fps <= 0.0 or fps > 60.0:
			reader.error("%s: fps must be greater than 0 and at most 60" % ctx)
		var values := reader.read_arr(d, "frames", ctx)
		if values.size() != 16:
			reader.error("%s: frames must contain four phases for each of four directions" % ctx)
		var frames: Array[Dictionary] = []
		for value: Variant in values:
			frames.append(_read_frame(value, texture, reader, ctx))
		if reader.errors.size() != before:
			continue
		_characters[str(key)] = {"texture": texture, "frames": frames, "fps": fps}
		if str(key) != "player":
			_npcs.append(str(key))


## A stable design and pose for a person, or {} when this set has no character art.
func sprite(person_id: int, is_player: bool, facing: Vector2, walking: bool, elapsed: float) -> Dictionary:
	var key := "player"
	if not is_player:
		if _npcs.is_empty():
			return {}
		key = _npcs[posmod(person_id, _npcs.size())]
	if not _characters.has(key):
		return {}
	var character: Dictionary = _characters[key]
	var phase := posmod(floori(elapsed * float(character["fps"])), 4) if walking else 1
	var index := direction_row(facing) * 4 + phase
	var frames: Array[Dictionary] = character["frames"]
	var result: Dictionary = frames[index].duplicate()
	result["texture"] = character["texture"]
	result["character"] = key
	result["frame"] = index
	return result


## Source rows follow the generated sheets: south, west, north, east.
static func direction_row(facing: Vector2) -> int:
	if absf(facing.x) > absf(facing.y):
		return 1 if facing.x < 0.0 else 3
	return 2 if facing.y < 0.0 else 0


static func _read_frame(value: Variant, texture: Texture2D, reader: ContentReader, ctx: String) -> Dictionary:
	var before := reader.errors.size()
	var d := reader.read_obj({"frame": value}, "frame", ctx)
	var rect := reader.read_coordinates(d, "rect", ctx, 4)
	var size := reader.read_coordinates(d, "size", ctx, 2)
	var offset := reader.read_coordinates(d, "offset", ctx, 2)
	if reader.errors.size() != before:
		return {}
	var region := Rect2i(rect[0], rect[1], rect[2], rect[3])
	if region.size.x < 1 or region.size.y < 1 or (texture != null and not Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())).encloses(region)):
		reader.error("%s: frame rect is outside the sheet or empty" % ctx)
	if size[0] < 1 or size[1] < 1 or size[0] > 64 or size[1] > 64:
		reader.error("%s: frame size must be between 1x1 and 64x64 pixels" % ctx)
	if abs(offset[0]) > 64 or abs(offset[1]) > 64:
		reader.error("%s: frame offset must stay within 64 pixels" % ctx)
	return {"region": region, "draw_rect": Rect2(Vector2(offset[0], offset[1]), Vector2(size[0], size[1]))}
