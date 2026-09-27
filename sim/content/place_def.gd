class_name PlaceDef
extends RefCounted
## A named area of a district (a shop, a flat, a square). Authored in district.json.
## Later milestones turn places into lots with owners, opening hours and access rules.

var id: String = ""
var name: String = ""
## "home" | "shop" | "bar" | "cafe" | "public" | "police" | "church" | "transit" | ...
var kind: String = ""
var level: int = 0
## Area in WORLD cell coordinates (district origin already applied).
var rect: Rect2i = Rect2i()


func contains(cell: Vector3i) -> bool:
	return cell.z == level and rect.has_point(Vector2i(cell.x, cell.y))
