class_name WorldGrid
extends RefCounted
## The town as a grid of cells. A cell is about 1 m x 1 m.
## Coordinates are Vector3i(x, y, level): x grows east, y grows south, level is the floor
## (0 = street level, 1 = first floor, -1 = basement or metro).
## Every cell holds a terrain index into ContentDB.terrains. Cells outside the grid count
## as "void" (not walkable).

var width: int = 0
var height: int = 0
## Bumped on every change, so caches (pathfinding, views) know when to rebuild.
var revision: int = 0

var _content: ContentDB
var _void_index: int = 0
var _levels: Dictionary[int, PackedInt32Array] = {}
## Derived from terrain, never saved: 1 = walkable.
var _walkable: Dictionary[int, PackedByteArray] = {}


func _init(p_content: ContentDB, p_width: int, p_height: int) -> void:
	_content = p_content
	width = p_width
	height = p_height
	_void_index = maxi(_content.terrain_index("void"), 0)


## Level numbers that exist, lowest first.
func levels() -> Array[int]:
	var out: Array[int] = []
	out.assign(_levels.keys())
	out.sort()
	return out


func has_level(level: int) -> bool:
	return _levels.has(level)


## Creates the level (filled with void) if it does not exist yet.
func ensure_level(level: int) -> void:
	if _levels.has(level):
		return
	var cells := PackedInt32Array()
	cells.resize(width * height)
	cells.fill(_void_index)
	_levels[level] = cells
	var walk := PackedByteArray()
	walk.resize(width * height)
	walk.fill(1 if _content.terrain(_void_index).walkable else 0)
	_walkable[level] = walk
	revision += 1


func in_bounds(c: Vector3i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height and _levels.has(c.z)


## Terrain index at a cell (void outside the grid).
func terrain_at(c: Vector3i) -> int:
	if not in_bounds(c):
		return _void_index
	return _levels[c.z][c.y * width + c.x]


func terrain_def_at(c: Vector3i) -> TerrainDef:
	return _content.terrain(terrain_at(c))


func set_terrain(c: Vector3i, terrain_index: int) -> void:
	if not in_bounds(c):
		return
	var i := c.y * width + c.x
	_levels[c.z][i] = terrain_index
	_walkable[c.z][i] = 1 if _content.terrain(terrain_index).walkable else 0
	revision += 1


func is_walkable(c: Vector3i) -> bool:
	if not in_bounds(c):
		return false
	return _walkable[c.z][c.y * width + c.x] == 1


## Writes ASCII rows (glyphs from data/terrain.json) with their top-left at `origin`.
## Unknown glyphs are skipped (ContentDB validation reports them).
func stamp_rows(level: int, origin: Vector2i, rows: PackedStringArray) -> void:
	ensure_level(level)
	for y: int in rows.size():
		var row := rows[y]
		for x: int in row.length():
			var index := _content.terrain_index_for_glyph(row[x])
			if index >= 0:
				set_terrain(Vector3i(origin.x + x, origin.y + y, level), index)


# --- Saving ------------------------------------------------------------------------------
# Terrain is saved as indices plus a palette of terrain ids. On load the palette maps the
# old indices to the current ones, so adding or reordering terrains never breaks saves.

func to_dict() -> Dictionary:
	var palette: Array[String] = []
	for t: TerrainDef in _content.terrains:
		palette.append(t.id)
	var levels_out: Dictionary = {}
	for level: int in levels():
		levels_out[str(level)] = Marshalls.raw_to_base64(_levels[level].to_byte_array())
	return {"width": width, "height": height, "palette": palette, "levels": levels_out}


static func from_dict(d: Dictionary, content: ContentDB) -> WorldGrid:
	var grid := WorldGrid.new(content, int(d["width"]), int(d["height"]))
	var remap: Array[int] = []
	for terrain_id: Variant in d["palette"]:
		var index := content.terrain_index(String(terrain_id))
		remap.append(index if index >= 0 else grid._void_index)
	var levels_in: Dictionary = d["levels"]
	for key: Variant in levels_in:
		var level := String(key).to_int()
		grid.ensure_level(level)
		var saved := Marshalls.base64_to_raw(String(levels_in[key])).to_int32_array()
		for i: int in mini(saved.size(), grid.width * grid.height):
			var old_index := saved[i]
			var index := remap[old_index] if old_index >= 0 and old_index < remap.size() else grid._void_index
			grid.set_terrain(Vector3i(i % grid.width, i / grid.width, level), index)
	grid.revision = 0
	return grid
