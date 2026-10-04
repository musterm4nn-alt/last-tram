class_name PoliceTask
extends RefCounted
## A police officer on a call (T-0094): who they are after and where they are heading. Saved
## in World.police_tasks by officer id; PoliceSystem drives it.

var officer_id: int = 0
## The suspect.
var target_id: int = 0
## Where the officer is heading: the reported crime's cell at first, then wherever they last
## saw the suspect.
var last_seen: Vector3i = Vector3i.ZERO
## True while the officer walks back to the desk after an arrest.
var returning: bool = false
## While the officer searches for a suspect they lost sight of: the tick they give up at
## (T-0095; -1 = not searching).
var search_until: int = -1


func to_dict() -> Dictionary:
	return {
		"officer_id": officer_id,
		"target_id": target_id,
		"last_seen": Ser.cell(last_seen),
		"returning": returning,
		"search_until": search_until,
	}


static func from_dict(d: Dictionary) -> PoliceTask:
	var task := PoliceTask.new()
	task.officer_id = int(d["officer_id"])
	task.target_id = int(d["target_id"])
	task.last_seen = Ser.to_cell(d["last_seen"])
	task.returning = bool(d.get("returning", false))
	task.search_until = int(d.get("search_until", -1))
	return task
