class_name SetGentleWorkCommand
extends Command
## Switches every job between its own need profile and the shared gentle one
## (WorkSettings.gentle, T-0077). Takes effect at the next minute of work.

var gentle: bool = false


func _init(p_gentle: bool = false) -> void:
	gentle = p_gentle


func type_id() -> String:
	return "set_gentle_work"


func apply(sim: Sim) -> void:
	sim.world.work.gentle = gentle


func to_dict() -> Dictionary:
	return {"person_id": 0, "gentle": gentle}


func load_dict(d: Dictionary) -> void:
	gentle = bool(d["gentle"])
