class_name CancelActionCommand
extends Command
## Removes one action from a person's queue (index 0 is the current one).
## Cancelling the front action while it performs stops it at once, and while the
## person walks to its object it also stops the walk. Ignored when the person is
## unknown or the index is out of range.

var person_id: int = 0
var index: int = 0


func _init(p_person_id: int = 0, p_index: int = 0) -> void:
	person_id = p_person_id
	index = p_index


func type_id() -> String:
	return "cancel_action"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	if index < 0 or index >= person.action_queue.size():
		return
	var removed: Action = person.action_queue[index]
	person.action_queue.remove_at(index)
	if index == 0 and removed.state == Action.ROUTING:
		person.path.clear()
	sim.emit_event(&"action_cancelled", {"person_id": person_id, "interaction_id": removed.interaction_id, "reason": "player"})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "index": index}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	index = int(d["index"])
