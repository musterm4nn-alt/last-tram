class_name Relationship
extends RefCounted
## One person's view of another (a directed edge, saved on the viewer by the other's id).
## docs/design/people.md → "Relationships". Values are clamped to their ranges by Social.

## Ranges per value: [min, max].
const RANGES: Dictionary = {
	"familiarity": [0.0, 100.0],
	"friendship": [-100.0, 100.0],
	"romance": [0.0, 100.0],
	"trust": [-100.0, 100.0],
	"fear": [0.0, 100.0],
}

var other_id: int = 0
## Stranger (0) → knows well (100).
var familiarity: float = 0.0
## Enemy (−100) ↔ best friend (100).
var friendship: float = 0.0
var romance: float = 0.0
var trust: float = 0.0
var fear: float = 0.0
## Tick of the last contact (an exchange or a change); drift waits a while after it.
var last_contact_tick: int = 0


func value(key: String) -> float:
	return float(get(key))


func to_dict() -> Dictionary:
	return {
		"other_id": other_id, "familiarity": familiarity, "friendship": friendship,
		"romance": romance, "trust": trust, "fear": fear, "last_contact_tick": last_contact_tick,
	}


static func from_dict(d: Dictionary) -> Relationship:
	var r := Relationship.new()
	r.other_id = int(d["other_id"])
	for key: String in RANGES:
		var bounds: Array = RANGES[key]
		r.set(key, clampf(float(d.get(key, 0.0)), float(bounds[0]), float(bounds[1])))
	r.last_contact_tick = int(d.get("last_contact_tick", 0))
	return r
