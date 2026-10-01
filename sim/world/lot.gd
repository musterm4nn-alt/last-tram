class_name Lot
extends RefCounted
## A place as world state (runtime entity, saved): who may enter, and when. Made from the
## place's content at new game (SimFactory); later milestones add owners, rent and tenants.

const PUBLIC: String = "public"
const PRIVATE: String = "private"
## Open from open_hour to close_hour (see Lots.is_open).
const HOURS: String = "hours"
const ACCESS: PackedStringArray = [PUBLIC, PRIVATE, HOURS]

var id: int = 0
## The PlaceDef this lot covers.
var place_id: String = ""
## One of ACCESS.
var access: String = PUBLIC
## Whole hours 0..24 (only for HOURS). close_hour < open_hour means open past midnight.
var open_hour: int = 0
var close_hour: int = 24


## A lot for `place`, with the place's access and hours.
static func from_place(lot_id: int, place: PlaceDef) -> Lot:
	var lot := Lot.new()
	lot.id = lot_id
	lot.place_id = place.id
	lot.access = place.access
	lot.open_hour = place.open_hour
	lot.close_hour = place.close_hour
	return lot


func to_dict() -> Dictionary:
	return {
		"id": id,
		"place_id": place_id,
		"access": access,
		"open_hour": open_hour,
		"close_hour": close_hour,
	}


static func from_dict(d: Dictionary) -> Lot:
	var lot := Lot.new()
	lot.id = int(d["id"])
	lot.place_id = String(d["place_id"])
	lot.access = String(d["access"])
	lot.open_hour = int(d.get("open_hour", 0))
	lot.close_hour = int(d.get("close_hour", 24))
	return lot
