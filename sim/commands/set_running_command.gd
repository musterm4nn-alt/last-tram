class_name SetRunningCommand
extends Command
## Running on or off (the player holds Shift). A running person moves at
## Person.RUN_FACTOR times their walking speed, both with direct control and along paths.
## Ignored for an unknown person. Does not count as input for AutonomySystem's idle wait.

var person_id: int = 0
var running: bool = false


func _init(p_person_id: int = 0, p_running: bool = false) -> void:
	person_id = p_person_id
	running = p_running


func type_id() -> String:
	return "set_running"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.running = running


func to_dict() -> Dictionary:
	return {"person_id": person_id, "running": running}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	running = bool(d["running"])
