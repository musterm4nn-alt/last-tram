extends SceneTree
## Builds the "kenney" art set for the art gate: art/export/kenney/terrain.png and
## objects.png plus data/art2d/kenney.json, from Kenney's CC0 sheets in this folder
## (Roguelike Modern City, packed; Roguelike Indoors, 1 px spacing) and a few pieces drawn
## here in the same flat style where the packs have nothing (tram rails, TV, shower,
## laptop, tram shelter).
## Run: godot --headless --path . --script res://art/src/kenney/build_kenney.gd

const DIR: String = "res://art/src/kenney/"
const OUT: String = "res://art/export/kenney/"
const CITY: String = "city"
const INDOOR: String = "indoor"
const OUTLINE: Color = Color("#3a3a46")

## terrain id -> variants; each variant is a list of layers drawn in order:
## [sheet, col, row] or the name of a drawing function.
const TERRAIN: Dictionary = {
	"sidewalk": [[[CITY, 2, 24]], [[CITY, 3, 24]]],
	"cobblestone": [[[CITY, 8, 24]]],
	"road": [[[CITY, 10, 19]]],
	"tram_track": [[[CITY, 10, 19], "rails"]],
	"crossing": [[[CITY, 9, 22]]],
	"grass": [[[CITY, 0, 24]], [[CITY, 1, 24]]],
	"tree": [[[CITY, 0, 24], [CITY, 33, 13]]],
	"fountain": [[[CITY, 27, 5]]],
	"wall": [[[CITY, 9, 5]], [[CITY, 10, 5]]],
	"window": [[[CITY, 9, 5], [CITY, 26, 16]]],
	"door": [[[CITY, 22, 16], [CITY, 29, 16]]],
	"floor_wood": [[[CITY, 22, 16]], [[CITY, 23, 16]]],
	"floor_tile": [[[CITY, 17, 1]], [[CITY, 18, 1]]],
}

## object def id -> [sheet, col, row, width in tiles, height in tiles], or a drawing
## function name with its size in pixels: ["draw", name, w, h].
const OBJECTS: Dictionary = {
	"bench": [CITY, 17, 15, 2, 1],
	"street_lamp": [CITY, 2, 16, 1, 3],
	"atm": [CITY, 26, 8, 1, 1],
	"notice_case": [CITY, 18, 8, 1, 1],
	"bed_double": [INDOOR, 12, 6, 2, 2],
	"sofa": [INDOOR, 14, 11, 2, 2],
	"wardrobe": [INDOOR, 25, 11, 1, 2],
	"fridge": [INDOOR, 11, 15, 1, 2],
	"stove": [INDOOR, 14, 14, 1, 1],
	"sink": [INDOOR, 8, 12, 1, 1],
	"kitchen_table": [INDOOR, 4, 3, 2, 1],
	"desk": ["draw", "desk", 16, 16],
	"tv": ["draw", "tv", 16, 20],
	"shower": ["draw", "shower", 16, 16],
	"tram_stop": ["draw", "shelter", 96, 32],
}

var _sheets: Dictionary = {}


func _initialize() -> void:
	quit.call_deferred(0)
	_sheets[CITY] = _load("roguelike_modern_city.png")
	_sheets[INDOOR] = _load("roguelike_indoors.png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var art := {"name": "Kenney (CC0 packs)", "sheets": {"terrain": OUT + "terrain.png", "objects": OUT + "objects.png"}}
	art["terrain"] = _build_terrain()
	art["objects"] = _build_objects()
	var file := FileAccess.open("res://data/art2d/kenney.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(art, "\t") + "\n")
	print("built the kenney art set")


func _build_terrain() -> Dictionary:
	var count := 0
	for variants: Array in TERRAIN.values():
		count += variants.size()
	var image := Image.create_empty(count * 16, 16, false, Image.FORMAT_RGBA8)
	var mapping := {}
	var col := 0
	for terrain_id: String in TERRAIN:
		var variants: Array = TERRAIN[terrain_id]
		mapping[terrain_id] = {"sheet": "terrain", "cell": [col, 0], "variants": variants.size()}
		for layers: Array in variants:
			for layer: Variant in layers:
				if layer is String:
					call("_draw_" + layer, image, Vector2i(col * 16, 0))
				else:
					_blit(image, layer[0], layer[1], layer[2], 1, 1, Vector2i(col * 16, 0))
			col += 1
	image.save_png(OUT + "terrain.png")
	return mapping


func _build_objects() -> Dictionary:
	var sizes := {}
	var width := 0
	for def_id: String in OBJECTS:
		var spec: Array = OBJECTS[def_id]
		var size := Vector2i(spec[2], spec[3]) if spec[0] == "draw" else Vector2i(spec[3], spec[4]) * 16
		sizes[def_id] = size
		width += size.x
	var image := Image.create_empty(width, 48, false, Image.FORMAT_RGBA8)
	var mapping := {}
	var x := 0
	for def_id: String in OBJECTS:
		var spec: Array = OBJECTS[def_id]
		var size: Vector2i = sizes[def_id]
		if spec[0] == "draw":
			call("_draw_" + spec[1], image, Vector2i(x, 0))
		else:
			_blit(image, spec[0], spec[1], spec[2], spec[3], spec[4], Vector2i(x, 0))
		mapping[def_id] = {"sheet": "objects", "rect": [x, 0, size.x, size.y]}
		x += size.x
	image.save_png(OUT + "objects.png")
	return mapping


func _load(file_name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIR + file_name))
	image.convert(Image.FORMAT_RGBA8)
	return image


## Draws w x h tiles from a sheet (alpha-blended) at `at`.
func _blit(image: Image, sheet: String, col: int, row: int, w: int, h: int, at: Vector2i) -> void:
	var step := 17 if sheet == INDOOR else 16
	var src: Image = _sheets[sheet]
	for ty: int in h:
		for tx: int in w:
			var from := Vector2i((col + tx) * step, (row + ty) * step)
			image.blend_rect(src, Rect2i(from, Vector2i(16, 16)), at + Vector2i(tx * 16, ty * 16))


func _box(image: Image, rect: Rect2i, fill: Color) -> void:
	image.fill_rect(rect, OUTLINE)
	image.fill_rect(rect.grow(-1), fill)


## Two steel rails along the cell, with sleepers between.
func _draw_rails(image: Image, at: Vector2i) -> void:
	for x: int in range(1, 16, 4):
		image.fill_rect(Rect2i(at + Vector2i(x, 3), Vector2i(2, 10)), Color("#4a4038"))
	for y: int in [4, 11]:
		image.fill_rect(Rect2i(at + Vector2i(0, y), Vector2i(16, 2)), Color("#8d939b"))
		image.fill_rect(Rect2i(at + Vector2i(0, y), Vector2i(16, 1)), Color("#c3c8ce"))


## A small table with an open laptop.
func _draw_desk(image: Image, at: Vector2i) -> void:
	_blit(image, INDOOR, 6, 3, 1, 1, at)
	_box(image, Rect2i(at + Vector2i(4, 2), Vector2i(8, 5)), Color("#2d3440"))
	image.fill_rect(Rect2i(at + Vector2i(5, 3), Vector2i(6, 3)), Color("#7fb6d9"))
	_box(image, Rect2i(at + Vector2i(3, 7), Vector2i(10, 3)), Color("#9aa1ab"))


## A flat TV on a low wooden stand (taller than its cell).
func _draw_tv(image: Image, at: Vector2i) -> void:
	_box(image, Rect2i(at + Vector2i(1, 13), Vector2i(14, 7)), Color("#a86f43"))
	image.fill_rect(Rect2i(at + Vector2i(2, 16), Vector2i(12, 1)), Color("#7d4f2e"))
	_box(image, Rect2i(at + Vector2i(0, 1), Vector2i(16, 11)), Color("#22262e"))
	image.fill_rect(Rect2i(at + Vector2i(2, 3), Vector2i(12, 7)), Color("#3c5a74"))
	image.fill_rect(Rect2i(at + Vector2i(3, 4), Vector2i(4, 1)), Color("#6d8ea8"))
	image.fill_rect(Rect2i(at + Vector2i(7, 12), Vector2i(2, 1)), OUTLINE)


## A white shower tray with a drain and a glass screen.
func _draw_shower(image: Image, at: Vector2i) -> void:
	_box(image, Rect2i(at, Vector2i(16, 16)), Color("#e8eef2"))
	image.fill_rect(Rect2i(at + Vector2i(2, 2), Vector2i(12, 12)), Color("#d3dde4"))
	image.fill_rect(Rect2i(at + Vector2i(7, 7), Vector2i(2, 2)), Color("#8a97a1"))
	image.fill_rect(Rect2i(at + Vector2i(1, 1), Vector2i(1, 14)), Color("#a9d4ea"))
	image.fill_rect(Rect2i(at + Vector2i(12, 1), Vector2i(2, 2)), Color("#9aa1ab"))


## A glass tram shelter with a green roof edge and a yellow stop sign.
func _draw_shelter(image: Image, at: Vector2i) -> void:
	_box(image, Rect2i(at + Vector2i(0, 8), Vector2i(96, 24)), Color("#b9d5df"))
	for x: int in range(16, 96, 16):
		image.fill_rect(Rect2i(at + Vector2i(x, 9), Vector2i(1, 22)), Color("#7d8a93"))
	image.fill_rect(Rect2i(at + Vector2i(1, 24), Vector2i(94, 7)), Color("#9fbecb"))
	_box(image, Rect2i(at + Vector2i(0, 4), Vector2i(96, 6)), Color("#3f8f5a"))
	image.fill_rect(Rect2i(at + Vector2i(1, 5), Vector2i(94, 1)), Color("#6fbf86"))
	_box(image, Rect2i(at + Vector2i(84, 0), Vector2i(10, 10)), Color("#f2c14e"))
	image.fill_rect(Rect2i(at + Vector2i(87, 3), Vector2i(4, 4)), Color("#3f8f5a"))
	_box(image, Rect2i(at + Vector2i(28, 20), Vector2i(40, 6)), Color("#a86f43"))
