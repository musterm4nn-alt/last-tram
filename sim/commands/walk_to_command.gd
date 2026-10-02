class_name WalkToCommand
extends Command
## Sends a person to a cell along a pathfound route. The path is followed by
## MovementSystem; direct WASD input (a non-zero move intent) overrides it. A walk with no
## way there isn't input (T-0077).

var person_id: int = 0
var target: Vector3i = Vector3i.ZERO


func _init(p_person_id: int = 0, p_target: Vector3i = Vector3i.ZERO) -> void:
	person_id = p_person_id
	target = p_target


func type_id() -> String:
	return "walk_to"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	if target == person.cell():
		person.last_input_tick = sim.clock.tick
		ActionSystem.cancel_front(sim, person, "walked")
		person.path.clear()
		person.move_intent = Vector2.ZERO
		return
	var path := sim.nav.find_path(person.cell(), target)
	if path.is_empty():
		sim.emit_event(&"path_failed", {"person_id": person_id, "target": Ser.cell(target)})
	else:
		person.last_input_tick = sim.clock.tick
		ActionSystem.cancel_front(sim, person, "walked")
		person.path = path
		person.move_intent = Vector2.ZERO


func to_dict() -> Dictionary:
	return {"person_id": person_id, "target": Ser.cell(target)}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	target = Ser.to_cell(d["target"])
