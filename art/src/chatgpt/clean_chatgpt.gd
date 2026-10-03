extends SceneTree
## Builds the "chatgpt" art set for the art gate from two ChatGPT Images concept sheets in
## this folder (tiles_concept.png, objects_concept.png: 4x4 grids on magenta): finds the
## grid, shrinks each cell by averaging (tiles to 16x16, objects to their footprint width),
## makes the magenta transparent, and locks every pixel to the project palette (the same one
## as route B). Writes art/export/chatgpt/{terrain,objects}.png and data/art2d/chatgpt.json.
## Run: godot --headless --path . --script res://art/src/chatgpt/clean_chatgpt.gd

const DIR: String = "res://art/src/chatgpt/"
const OUT: String = "res://art/export/chatgpt/"
const PALETTE: PackedStringArray = [
	"1e1c22", "2c2d31", "2f5246", "34502a", "355f78", "36373c", "3e5429", "3f6b5a", "414248",
	"46683a", "4b4c53", "4c6632", "4f7f99", "554c46", "585a61", "5a5e64", "5c8344", "5d7a3e",
	"5e3f29", "5f8f7a", "6e3626", "6e6a66", "6fa0b8", "71994f", "728f4a", "73685f", "7a5a2e",
	"7d5536", "85807a", "867a6f", "86b39c", "8aa65a", "8d939b", "8e4a32", "8fb8c9", "966644",
	"978a7d", "9c7638", "9c968e", "a39d90", "a85e3c", "a9cfe0", "ab7b52", "ab9d8e", "b2aba1",
	"b98f47", "c27a52", "c29164", "c2bcae", "c4c9ce", "c4dde6", "c7c0b4", "cfa95f", "d97a9a",
	"d9d4c7", "e0c486", "e8b83a", "e8e3d8", "ece6d8", "f4d47a", "f6d58e", "f8f5ee",
]
## terrain id -> grid cells [col, row] of tiles_concept.png, one per variant. The fountain
## uses a crop of its water only (a whole fountain in every cell of the 2x2 basin looks wrong).
const TERRAIN: Dictionary = {
	"sidewalk": [[0, 0], [1, 0]],
	"cobblestone": [[2, 0], [3, 0]],
	"road": [[0, 1]],
	"tram_track": [[1, 1]],
	"crossing": [[2, 1]],
	"grass": [[3, 1]],
	"tree": [[0, 2]],
	"fountain": [[1, 2]],
	"wall": [[2, 2], [2, 2], [3, 3]],
	"window": [[3, 2]],
	"door": [[0, 3]],
	"floor_wood": [[1, 3]],
	"floor_tile": [[2, 3]],
}
## object def id -> [col, row] in objects_concept.png (an even 4x4 split: the objects stand on
## plain magenta, no grid lines) and the sprite width in pixels. The shelter's stop sign
## pokes into the next cell, so it has its own crop (SHELTER_RECT).
const OBJECTS: Dictionary = {
	"bench": [[0, 0], 32], "street_lamp": [[1, 0], 16], "atm": [[2, 0], 16], "notice_case": [[3, 0], 16],
	"bed_double": [[0, 1], 32], "sofa": [[1, 1], 32], "wardrobe": [[2, 1], 16], "fridge": [[3, 1], 16],
	"stove": [[0, 2], 16], "sink": [[1, 2], 16], "kitchen_table": [[2, 2], 32], "desk": [[3, 2], 16],
	"tv": [[0, 3], 16], "shower": [[1, 3], 16], "tram_stop": [[2, 3], 96],
}

const SHELTER_RECT: Rect2i = Rect2i(620, 935, 372, 280)

var _palette: Array[Color] = []


func _initialize() -> void:
	quit.call_deferred(0)
	for code: String in PALETTE:
		_palette.append(Color("#" + code))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var art := {"name": "ChatGPT Images, cleaned up", "sheets": {"terrain": OUT + "terrain.png"}}
	art["terrain"] = _build_terrain(_load("tiles_concept.png"))
	if FileAccess.file_exists(DIR + "objects_concept.png"):
		art["sheets"]["objects"] = OUT + "objects.png"
		art["objects"] = _build_objects(_load("objects_concept.png"))
	var file := FileAccess.open("res://data/art2d/chatgpt.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(art, "\t") + "\n")
	print("built the chatgpt art set")


func _build_terrain(src: Image) -> Dictionary:
	var cells := _grid(src)
	var count := 0
	for variants: Array in TERRAIN.values():
		count += variants.size()
	var out := Image.create_empty(count * 16, 16, false, Image.FORMAT_RGBA8)
	var mapping := {}
	var col := 0
	for terrain_id: String in TERRAIN:
		var variants: Array = TERRAIN[terrain_id]
		mapping[terrain_id] = {"sheet": "terrain", "cell": [col, 0], "variants": variants.size()}
		for i: int in variants.size():
			var at: Array = variants[i]
			var rect: Rect2i = cells[at[1]][at[0]].grow(-6)
			if terrain_id == "fountain":  # the water ring between the rim and the spout
				rect = Rect2i(rect.position + Vector2i(rect.size.x * 20 / 100, rect.size.y * 42 / 100), rect.size * 16 / 100)
			if terrain_id == "wall" and i == 1:  # plaster only: the left half of the cracked wall's top
				rect = Rect2i(rect.position + Vector2i(rect.size.x / 2, 0), rect.size / 2)
			var tile := _shrink(src, rect, Vector2i(16, 16))
			out.blit_rect(tile, Rect2i(0, 0, 16, 16), Vector2i(col * 16, 0))
			col += 1
	out.save_png(OUT + "terrain.png")
	return mapping


func _build_objects(src: Image) -> Dictionary:
	var cell_size := src.get_size() / 4
	var sprites := {}
	var width := 0
	for def_id: String in OBJECTS:
		var spec: Array = OBJECTS[def_id]
		var cell := Rect2i(Vector2i(spec[0][0], spec[0][1]) * cell_size, cell_size).grow(-2)
		if def_id == "tram_stop":
			cell = SHELTER_RECT
		var bounds := _content_bounds(src, cell)
		var w: int = spec[1]
		var h := clampi(roundi(float(bounds.size.y) * w / bounds.size.x), 8, 48)
		sprites[def_id] = _shrink(src, bounds, Vector2i(w, h))
		width += w
	var out := Image.create_empty(width, 48, false, Image.FORMAT_RGBA8)
	var mapping := {}
	var x := 0
	for def_id: String in OBJECTS:
		var sprite: Image = sprites[def_id]
		out.blit_rect(sprite, Rect2i(Vector2i.ZERO, sprite.get_size()), Vector2i(x, 0))
		mapping[def_id] = {"sheet": "objects", "rect": [x, 0, sprite.get_width(), sprite.get_height()]}
		x += sprite.get_width()
	out.save_png(OUT + "objects.png")
	return mapping


func _load(file_name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIR + file_name))
	image.convert(Image.FORMAT_RGBA8)
	return image


static func _magenta(c: Color) -> bool:
	return c.r > 0.75 and c.g < 0.35 and c.b > 0.75


## The 4x4 cells between the magenta lines: cells[row][col] as pixel rects.
func _grid(src: Image) -> Array:
	var xs := _spans(src, true)
	var ys := _spans(src, false)
	var cells := []
	for row: int in 4:
		var line := []
		for col: int in 4:
			line.append(Rect2i(xs[col].x, ys[row].x, xs[col].y - xs[col].x, ys[row].y - ys[row].x))
		cells.append(line)
	return cells


## [start, end) of the four non-magenta runs along the image (by columns or rows), found by
## counting magenta pixels across the whole image per column or row.
func _spans(src: Image, by_column: bool) -> Array[Vector2i]:
	var n := src.get_width() if by_column else src.get_height()
	var m := src.get_height() if by_column else src.get_width()
	var spans: Array[Vector2i] = []
	var start := -1
	for i: int in n:
		var magenta := 0
		for j: int in range(0, m, 4):
			if _magenta(src.get_pixel(i, j) if by_column else src.get_pixel(j, i)):
				magenta += 1
		var line := magenta * 4 > m * 6 / 10
		if not line and start < 0:
			start = i
		elif line and start >= 0:
			spans.append(Vector2i(start, i))
			start = -1
	if start >= 0:
		spans.append(Vector2i(start, n))
	var big: Array[Vector2i] = []
	for span: Vector2i in spans:
		if span.y - span.x > n / 10:
			big.append(span)
	return big


## The box around the non-magenta pixels in `cell`.
func _content_bounds(src: Image, cell: Rect2i) -> Rect2i:
	var lo := cell.end
	var hi := cell.position
	for y: int in range(cell.position.y, cell.end.y):
		for x: int in range(cell.position.x, cell.end.x):
			if not _magenta(src.get_pixel(x, y)):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x + 1), maxi(hi.y, y + 1))
	return Rect2i(lo, hi - lo)


## `rect` of src averaged down to `size`, magenta made transparent, colours palette-locked.
func _shrink(src: Image, rect: Rect2i, size: Vector2i) -> Image:
	var out := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for ty: int in size.y:
		for tx: int in size.x:
			var x0 := rect.position.x + tx * rect.size.x / size.x
			var x1 := maxi(x0 + 1, rect.position.x + (tx + 1) * rect.size.x / size.x)
			var y0 := rect.position.y + ty * rect.size.y / size.y
			var y1 := maxi(y0 + 1, rect.position.y + (ty + 1) * rect.size.y / size.y)
			var sum := Color(0, 0, 0, 0)
			var opaque := 0
			var total := 0
			for y: int in range(y0, y1):
				for x: int in range(x0, x1):
					var c := src.get_pixel(x, y)
					total += 1
					if not _magenta(c):
						sum += c
						opaque += 1
			if opaque * 2 <= total:
				continue
			var avg := sum / float(opaque)
			out.set_pixel(tx, ty, _nearest(_punch(avg)))
	return out


## A little more contrast and colour, which averaging washes out.
static func _punch(c: Color) -> Color:
	var grey := c.get_luminance()
	var s := Color(grey, grey, grey).lerp(c, 1.05)
	return Color(clampf((s.r - 0.5) * 1.08 + 0.5, 0, 1), clampf((s.g - 0.5) * 1.08 + 0.5, 0, 1), clampf((s.b - 0.5) * 1.08 + 0.5, 0, 1))


## The closest palette colour ("redmean" weighted distance).
func _nearest(c: Color) -> Color:
	var best := _palette[0]
	var best_d := INF
	for p: Color in _palette:
		var rm := (c.r + p.r) / 2.0
		var dr := c.r - p.r
		var dg := c.g - p.g
		var db := c.b - p.b
		var d := (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db
		if d < best_d:
			best_d = d
			best = p
	return best
