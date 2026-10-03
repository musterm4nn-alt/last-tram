extends SceneTree
## PixelLab test (art/pixellab-test branch only): builds art/export/pixellab/ from the raw
## PixelLab downloads in art/src/pixellab/raw/ (config: art/src/pixellab/build.json).
## - terrain.png: one row of 16 corner tiles per terrain pair, locked to route B's palette.
##   Colours of the all-lower tile take the lower ramp, of the all-upper tile the upper ramp,
##   the rest (kerbs, edge stones) the edge ramp; brightness picks the step on the ramp.
## - objects.png: each object cropped to its pixels, bottom-centred in its "size" box, dark
##   colours (v < 0.3) on the dark ramp and the rest on its main ramp, by brightness.
## - resident.png: 44x44 frames, rows south, east, north, west; walk frames, then idle.
## Prints the "wang" entries for data/art2d/pixellab.json.
##   godot --headless --path . --script res://art/src/pixellab/build_pixellab.gd

const SRC: String = "res://art/src/pixellab/"
const OUT: String = "res://art/export/pixellab/"
const PX: int = 16
const FRAME: int = 44
const DIRS: Array[String] = ["south", "east", "north", "west"]
## How close (RGB distance) a transition-only colour must be to a terrain's mean to join it.
const JOIN_DISTANCE: float = 0.2


func _initialize() -> void:
	quit.call_deferred(0)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC + "build.json"))
	var palette: Dictionary = config["palette"]
	var pairs: Array = config["pairs"]
	var terrain := Image.create_empty(PX * 16, PX * pairs.size(), false, Image.FORMAT_RGBA8)
	var wang: Array = []
	for row: int in pairs.size():
		var pair: Dictionary = pairs[row]
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC + "raw/tiles/%s.png" % pair["raw"]))
		sheet.convert(Image.FORMAT_RGBA8)
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SRC + "raw/tiles/%s.json" % pair["raw"]))
		var tiles: Array = meta["tileset_data"]["tiles"]
		_lock(sheet, tiles, [_ramp(palette, pair["lower_ramp"]), _ramp(palette, pair["upper_ramp"]), _ramp(palette, pair["edge_ramp"])])
		var keys: Dictionary = {}
		for col: int in tiles.size():
			var tile: Dictionary = tiles[col]
			var c: Dictionary = tile["corners"]
			var key := ""
			for corner: String in ["NW", "NE", "SW", "SE"]:
				key += "1" if c[corner] == "upper" else "0"
			terrain.blit_rect(sheet, _box(tile), Vector2i(col * PX, row * PX))
			keys[key] = [col, row]
		wang.append({"sheet": "terrain", "lower": pair["lower"], "upper": pair["upper"], "tiles": keys})
	terrain.save_png(ProjectSettings.globalize_path(OUT + "terrain.png"))
	_build_resident(config["resident"])
	_build_objects(config["objects"], palette)
	print(JSON.stringify({"wang": wang}, "\t"))


func _build_objects(specs: Array, palette: Dictionary) -> void:
	var width := 0
	var height := 0
	for spec: Dictionary in specs:
		width += int(spec["size"][0])
		height = maxi(height, int(spec["size"][1]))
	var out := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	var x := 0
	for spec: Dictionary in specs:
		var image := Image.load_from_file(ProjectSettings.globalize_path(SRC + "raw/objects/%s.png" % spec["raw"]))
		image.convert(Image.FORMAT_RGBA8)
		image = image.get_region(image.get_used_rect())
		var dark: Array = []
		var main: Array = []
		for key: String in _colors(image, Rect2i(Vector2i.ZERO, image.get_size())):
			(dark if Color(key).v < 0.3 else main).append(key)
		var mapping: Dictionary = {}
		_map_by_brightness(dark, _ramp(palette, spec["dark_ramp"]), mapping)
		_map_by_brightness(main, _ramp(palette, spec["main_ramp"]), mapping)
		for py: int in image.get_height():
			for px: int in image.get_width():
				var c := image.get_pixel(px, py)
				image.set_pixel(px, py, mapping[c.to_html()] if c.a >= 0.5 else Color(0, 0, 0, 0))
		var size := Vector2i(int(spec["size"][0]), int(spec["size"][1]))
		out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x + (size.x - image.get_width()) / 2, size.y - image.get_height()))
		print("%s: rect [%d, 0, %d, %d]" % [spec["raw"], x, size.x, size.y])
		x += size.x
	out.save_png(ProjectSettings.globalize_path(OUT + "objects.png"))


func _map_by_brightness(keys: Array, ramp: PackedColorArray, mapping: Dictionary) -> void:
	var lo := 1.0
	var hi := 0.0
	for key: String in keys:
		lo = minf(lo, Color(key).get_luminance())
		hi = maxf(hi, Color(key).get_luminance())
	for key: String in keys:
		var t := 0.5 if hi - lo < 0.001 else (Color(key).get_luminance() - lo) / (hi - lo)
		mapping[key] = ramp[clampi(int(t * ramp.size()), 0, ramp.size() - 1)]


func _build_resident(spec: Dictionary) -> void:
	var walk: int = spec["walk_frames"]
	var idle: int = spec["idle_frames"]
	var out := Image.create_empty(FRAME * (walk + idle), FRAME * DIRS.size(), false, Image.FORMAT_RGBA8)
	for row: int in DIRS.size():
		for f: int in walk + idle:
			var file := "%s_%d.png" % [DIRS[row], f] if f < walk else "%s_idle_%d.png" % [DIRS[row], f - walk]
			var path := ProjectSettings.globalize_path(SRC + "raw/resident/" + file)
			if not FileAccess.file_exists(path):
				path = ProjectSettings.globalize_path(SRC + "raw/resident/%s_rot.png" % DIRS[row])
			var frame := Image.load_from_file(path)
			frame.convert(Image.FORMAT_RGBA8)
			out.blit_rect(frame, Rect2i(0, 0, FRAME, FRAME), Vector2i(f * FRAME, row * FRAME))
	out.save_png(ProjectSettings.globalize_path(OUT + "resident.png"))


func _lock(sheet: Image, tiles: Array, ramps: Array) -> void:
	var groups: Array[Dictionary] = [{}, {}, {}]
	for tile: Dictionary in tiles:
		var kinds: Array = (tile["corners"] as Dictionary).values()
		var group := 0 if kinds.count("lower") == 4 else (1 if kinds.count("upper") == 4 else -1)
		if group >= 0:
			for key: String in _colors(sheet, _box(tile)):
				groups[group][key] = true
	# A colour only the transition tiles use joins the terrain it is close to (chained
	# tilesets redraw the terrains a little); otherwise it is an edge colour.
	var means: Array[Color] = [_mean(groups[0].keys()), _mean(groups[1].keys())]
	for key: String in _colors(sheet, Rect2i(Vector2i.ZERO, sheet.get_size())):
		if groups[0].has(key) or groups[1].has(key):
			continue
		var d0 := _distance(Color(key), means[0])
		var d1 := _distance(Color(key), means[1])
		if minf(d0, d1) < JOIN_DISTANCE:
			groups[0 if d0 < d1 else 1][key] = true
		else:
			groups[2][key] = true
	var mapping: Dictionary = {}
	for g: int in 3:
		var lo := 1.0
		var hi := 0.0
		for key: String in groups[g]:
			lo = minf(lo, Color(key).get_luminance())
			hi = maxf(hi, Color(key).get_luminance())
		var ramp: PackedColorArray = ramps[g]
		for key: String in groups[g]:
			if mapping.has(key):
				continue
			var t := 0.5 if hi - lo < 0.001 else (Color(key).get_luminance() - lo) / (hi - lo)
			mapping[key] = ramp[clampi(int(t * ramp.size()), 0, ramp.size() - 1)]
	for y: int in sheet.get_height():
		for x: int in sheet.get_width():
			var c := sheet.get_pixel(x, y)
			if c.a >= 0.5:
				sheet.set_pixel(x, y, mapping[c.to_html()])


func _mean(keys: Array) -> Color:
	var sum := Color(0, 0, 0, 0)
	for key: String in keys:
		sum += Color(key)
	return Color(sum.r / keys.size(), sum.g / keys.size(), sum.b / keys.size())


func _distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _ramp(palette: Dictionary, names: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for n: String in names:
		out.append(Color(palette[n]))
	return out


func _box(tile: Dictionary) -> Rect2i:
	var b: Dictionary = tile["bounding_box"]
	return Rect2i(int(b["x"]), int(b["y"]), int(b["width"]), int(b["height"]))


func _colors(image: Image, rect: Rect2i) -> Array[String]:
	var seen: Dictionary = {}
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := image.get_pixel(x, y)
			if c.a >= 0.5:
				seen[c.to_html()] = true
	var out: Array[String] = []
	out.assign(seen.keys())
	return out
