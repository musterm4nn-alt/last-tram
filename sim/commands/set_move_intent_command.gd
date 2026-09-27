class_name SetMoveIntentCommand
extends Command
## Direct control: the person walks in `direction` (length 0..1) until a new intent is set.
## Vector2.ZERO stops them.

var person_id: int = 0
var direction: Vector2 = Vector2.ZERO


func _init(p_person_id: int = 0, p_direction: Vector2 = Vector2.ZERO) -> void:
	person_id = p_person_id
	direction = p_direction.limit_length(1.0)


func type_id() -> String:
	return "set_move_intent"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.move_intent = direction.limit_length(1.0)


func to_dict() -> Dictionary:
	return {"person_id": person_id, "direction": Ser.vec2(direction)}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	direction = Ser.to_vec2(d["direction"])
