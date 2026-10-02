class_name QuitJobCommand
extends Command
## The phone's Jobs app (T-0064): leaves the person's job (Hiring.quit); unpaid wages are paid
## at once. Ignored for an unknown person or one without a job.

var person_id: int = 0


func _init(p_person_id: int = 0) -> void:
	person_id = p_person_id


func type_id() -> String:
	return "quit_job"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person != null:
		person.last_input_tick = sim.clock.tick
		Hiring.quit(sim, person)


func to_dict() -> Dictionary:
	return {"person_id": person_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
