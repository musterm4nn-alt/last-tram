class_name DayNight
extends RefCounted
## Day and night for the 2D view, as pure functions of the minute of the day (0-1439): the
## world's tint, how dark it is, which windows are lit, and the light map that NightLights2D
## draws (street lamps, lit windows, lit interiors). View only; the sim never sees it.

## Light map pixels per cell.
const LIGHT_PX: int = 4
const DAY: Color = Color(1.0, 1.0, 1.0)
const DUSK: Color = Color(0.86, 0.72, 0.70)
const NIGHT: Color = Color(0.30, 0.34, 0.52)
## [minute of the day, tint, darkness], in time order; wraps around midnight.
const KEYFRAMES: Array = [
	[300, NIGHT, 1.0],
	[420, DAY, 0.0],
	[1080, DAY, 0.0],
	[1170, DUSK, 0.35],
	[1260, NIGHT, 1.0],
]
## [from minute, percent of windows lit], in time order: each share lasts until the next.
const WINDOW_SHARES: Array = [
	[0, 30],
	[60, 5],
	[300, 30],
	[420, 0],
	[1080, 70],
	[1380, 30],
]
const LAMP_RADIUS_CELLS: float = 3.5
const WINDOW_RADIUS_CELLS: float = 1.5
## Light colours in the map (the light itself is white): added to the night tint, indoor
## cells come out a warm white, lamps sodium orange (art.md), lit windows a softer amber.
const INDOOR_LIGHT: Color = Color(0.68, 0.56, 0.36)
const LAMP_LIGHT: Color = Color(0.92, 0.56, 0.22)
const WINDOW_LIGHT: Color = Color(0.75, 0.55, 0.28)


## The world's CanvasModulate colour at this minute.
static func tint(minute_of_day: int) -> Color:
	var at := _between(minute_of_day)
	var a: Array = KEYFRAMES[at[0]]
	var b: Array = KEYFRAMES[at[1]]
	return (a[1] as Color).lerp(b[1], at[2])


## 0 by day, 1 at night (0.35 at dusk, so lit rooms don't glow too orange); lights scale with it.
static func darkness(minute_of_day: int) -> float:
	var at := _between(minute_of_day)
	return lerpf(KEYFRAMES[at[0]][2], KEYFRAMES[at[1]][2], at[2])


## Percent of windows lit at this minute.
static func window_share(minute_of_day: int) -> int:
	var minute := posmod(minute_of_day, 1440)
	var share: int = WINDOW_SHARES[WINDOW_SHARES.size() - 1][1]
	for entry: Array in WINDOW_SHARES:
		if minute >= int(entry[0]):
			share = entry[1]
	return share


## True if the window at this cell is lit at this minute (a fixed hash per cell).
static func window_lit(cell: Vector2i, minute_of_day: int) -> bool:
	return _cell_percent(cell) < window_share(minute_of_day)


## The light map for one floor: LIGHT_PX pixels per cell, RGB = the light added there. Indoor
## cells get INDOOR_LIGHT; each lamp adds a soft disc of LAMP_LIGHT, each lit window a
## smaller one of WINDOW_LIGHT, both outdoors only (they don't shine through walls into lit
## rooms). Channels are clamped to 1.
static func light_map(grid: WorldGrid, level: int, lamp_cells: Array[Vector2i], minute_of_day: int) -> Image:
	var w := grid.width * LIGHT_PX
	var h := grid.height * LIGHT_PX
	var light := PackedFloat32Array()
	light.resize(w * h * 3)
	var indoor := PackedByteArray()
	indoor.resize(grid.width * grid.height)
	for y: int in grid.height:
		for x: int in grid.width:
			indoor[y * grid.width + x] = 1 if grid.terrain_def_at(Vector3i(x, y, level)).indoor else 0
	for y: int in grid.height:
		for x: int in grid.width:
			var cell := Vector3i(x, y, level)
			var terrain := grid.terrain_def_at(cell)
			if indoor[y * grid.width + x] == 1:
				for py: int in LIGHT_PX:
					for px: int in LIGHT_PX:
						_add(light, (y * LIGHT_PX + py) * w + x * LIGHT_PX + px, INDOOR_LIGHT, 1.0)
			elif terrain.id == "window" and window_lit(Vector2i(x, y), minute_of_day):
				_add_disc(light, indoor, grid.width, Vector2i(x, y), WINDOW_RADIUS_CELLS, WINDOW_LIGHT)
	for lamp: Vector2i in lamp_cells:
		_add_disc(light, indoor, grid.width, lamp, LAMP_RADIUS_CELLS, LAMP_LIGHT)
	var bytes := PackedByteArray()
	bytes.resize(w * h * 3)
	for i: int in w * h * 3:
		bytes[i] = int(roundf(clampf(light[i], 0.0, 1.0) * 255.0))
	return Image.create_from_data(w, h, false, Image.FORMAT_RGB8, bytes)


## [index of the keyframe before, index after, weight 0-1] for a minute.
static func _between(minute_of_day: int) -> Array:
	var minute := posmod(minute_of_day, 1440)
	var n := KEYFRAMES.size()
	for i: int in n:
		var start: int = KEYFRAMES[i][0]
		var end: int = KEYFRAMES[(i + 1) % n][0]
		if end <= start:
			end += 1440
		var m := minute if minute >= start else minute + 1440
		if m >= start and m < end:
			return [i, (i + 1) % n, float(m - start) / float(end - start)]
	return [0, 0, 0.0]


## 0-99 for a cell, fixed and evenly spread.
static func _cell_percent(cell: Vector2i) -> int:
	var h := (cell.x * 2654435761) ^ (cell.y * 2246822519)
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	return posmod(h ^ (h >> 16), 100)


## Adds a soft disc of light (brightest in the middle of the cell) to the outdoor pixels of
## the map. `indoor` has one entry per grid cell, `cells_wide` cells per row.
static func _add_disc(light: PackedFloat32Array, indoor: PackedByteArray, cells_wide: int, cell: Vector2i, radius_cells: float, color: Color) -> void:
	var w := cells_wide * LIGHT_PX
	var h := indoor.size() / cells_wide * LIGHT_PX
	var centre := (Vector2(cell) + Vector2(0.5, 0.5)) * LIGHT_PX
	var radius := radius_cells * LIGHT_PX
	var r := ceili(radius)
	for py: int in range(maxi(0, floori(centre.y) - r), mini(h, ceili(centre.y) + r)):
		for px: int in range(maxi(0, floori(centre.x) - r), mini(w, ceili(centre.x) + r)):
			var d := (Vector2(px, py) + Vector2(0.5, 0.5)).distance_to(centre) / radius
			if d < 1.0 and indoor[(py / LIGHT_PX) * cells_wide + px / LIGHT_PX] == 0:
				_add(light, py * w + px, color, 1.0 - d * d)


static func _add(light: PackedFloat32Array, pixel: int, color: Color, amount: float) -> void:
	light[pixel * 3] += color.r * amount
	light[pixel * 3 + 1] += color.g * amount
	light[pixel * 3 + 2] += color.b * amount
