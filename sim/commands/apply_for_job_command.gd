class_name ApplyForJobCommand
extends Command
## The phone's Jobs app (T-0064): applies for a vacant position (Hiring.apply): an interview,
## and the job from tomorrow if it goes well. Ignored for an unknown person.

var person_id: int = 0
var job_id: String = ""
var position: int = 0


func _init(p_person_id: int = 0, p_job_id: String = "", p_position: int = 0) -> void:
	person_id = p_person_id
	job_id = p_job_id
	position = p_position


func type_id() -> String:
	return "apply_for_job"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person != null:
		person.last_input_tick = sim.clock.tick
		Hiring.apply(sim, person, job_id, position)


func to_dict() -> Dictionary:
	return {"person_id": person_id, "job_id": job_id, "position": position}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	job_id = String(d["job_id"])
	position = int(d["position"])
