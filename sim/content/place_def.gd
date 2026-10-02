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
## Lot.PUBLIC, Lot.PRIVATE or Lot.HOURS (district.json "access"; default by kind: home →
## private, shop/cafe/bar/restaurant must say "hours", the rest public).
var access: String = "public"
## Opening hours for "hours" access (district.json "hours": [open, close], whole hours 0..24).
var open_hour: int = 0
var close_hour: int = 24
## Weekdays it stays shut ("hours" access only; 0 = Monday … 6 = Sunday, like
## SimClock.weekday()). district.json "closed": ["sun"] (T-0056).
var closed_days: PackedInt32Array = PackedInt32Array()
## Weekly rent of a home, in euro cents (district.json "rent", T-0062); 0 for other places.
var rent: int = 0
## A secret place (T-0069): left off the map (and the HUD's place line) until the player
## uncovers a discovery there.
var hidden: bool = false


func contains(cell: Vector3i) -> bool:
	return cell.z == level and rect.has_point(Vector2i(cell.x, cell.y))
