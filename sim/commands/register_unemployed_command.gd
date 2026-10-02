class_name RegisterUnemployedCommand
extends Command
## The phone's Jobs app (T-0064): registers the person as unemployed (Hiring.register), so
## benefit is paid on Mondays while they have no job. Ignored for an unknown person.

var person_id: int = 0


func _init(p_person_id: int = 0) -> void:
	person_id = p_person_id


func type_id() -> String:
	return "register_unemployed"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person != null:
		person.last_input_tick = sim.clock.tick
		Hiring.register(sim, person)


func to_dict() -> Dictionary:
	return {"person_id": person_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
