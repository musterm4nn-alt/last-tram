class_name TerrainDef
extends RefCounted
## One kind of ground cell (floor, wall, road...). Defined in data/terrain.json.

var id: String = ""
var name: String = ""
## Single character used for this terrain in district ASCII maps.
var glyph: String = ""
var walkable: bool = false
var blocks_sight: bool = false
var indoor: bool = false
## "none" | "wall" | "floor" | "sidewalk" | "road" | "rail" | "grass" | "water"
var surface: String = "none"
## Cost of walking through a cell of this terrain (AStarGrid2D weight, >= 1.0).
## Pavements and floors are 1, grass is slower, roads are for jaywalking.
var path_cost: float = 1.0
## Colour of the placeholder tile (view) and debug tools. Not real art.
var debug_color: Color = Color.MAGENTA
