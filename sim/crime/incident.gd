class_name Incident
extends RefCounted
## One crime that happened (T-0091): who did what, to whom, where and when. Witnesses,
## reports and the police build on it. Saved in World.incidents.

var id: int = 0
## A CrimeDef id.
var crime_id: String = ""
## The person who committed it.
var perpetrator_id: int = 0
## The person or object it was done to (0 = none).
var target_id: int = 0
## Where it happened.
var cell: Vector3i = Vector3i.ZERO
## The lot it happened on (0 = none, e.g. the street).
var lot_id: int = 0
## Sim tick it happened at.
var tick: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"crime_id": crime_id,
		"perpetrator_id": perpetrator_id,
		"target_id": target_id,
		"cell": [cell.x, cell.y, cell.z],
		"lot_id": lot_id,
		"tick": tick,
	}


static func from_dict(d: Dictionary) -> Incident:
	var incident := Incident.new()
	incident.id = int(d["id"])
	incident.crime_id = String(d["crime_id"])
	incident.perpetrator_id = int(d["perpetrator_id"])
	incident.target_id = int(d["target_id"])
	var c: Array = d["cell"]
	incident.cell = Vector3i(int(c[0]), int(c[1]), int(c[2]))
	incident.lot_id = int(d["lot_id"])
	incident.tick = int(d["tick"])
	return incident
