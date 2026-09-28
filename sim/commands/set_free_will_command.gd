class_name SetFreeWillCommand
extends Command
## Turns a person's free will on or off (the Esc menu's "Free will" button). Ignored for an
## unknown person. Does not count as input for AutonomySystem's idle wait.

var person_id: int = 0
var enabled: bool = true


func _init(p_person_id: int = 0, p_enabled: bool = true) -> void:
	person_id = p_person_id
	enabled = p_enabled


func type_id() -> String:
	return "set_free_will"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.free_will = enabled


func to_dict() -> Dictionary:
	return {"person_id": person_id, "enabled": enabled}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	enabled = bool(d["enabled"])
