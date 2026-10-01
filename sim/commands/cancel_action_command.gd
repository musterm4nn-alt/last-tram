class_name CancelActionCommand
extends Command
## Removes a stable action id, or uses an index for legacy commands/replays.
## Cancelling the front action while it performs stops it at once, and while the
## person walks to its object it also stops the walk. Ignored when the person is
## unknown or the index is out of range.

var person_id: int = 0
var index: int = 0
## 0 means a legacy index command; new UI commands always capture the instance id.
var action_id: int = 0


func _init(p_person_id: int = 0, p_index: int = 0, p_action_id: int = 0) -> void:
	person_id = p_person_id
	index = p_index
	action_id = p_action_id


func type_id() -> String:
	return "cancel_action"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.last_input_tick = sim.clock.tick
	var current := index
	if action_id > 0:
		current = -1
		for candidate: int in person.action_queue.size():
			if person.action_queue[candidate].id == action_id:
				current = candidate
				break
	if current < 0 or current >= person.action_queue.size():
		return
	var removed: Action = person.action_queue[current]
	var removed_def := sim.content.interaction(removed.interaction_id)
	if removed_def != null and removed_def.work and removed.state == Action.PERFORMING:
		Jobs.end_shift(sim, person, removed, false)
	person.action_queue.remove_at(current)
	if current == 0 and removed.state == Action.ROUTING:
		person.path.clear()
	sim.emit_event(&"action_cancelled", {"person_id": person_id, "interaction_id": removed.interaction_id, "reason": "player", "performing": removed.state == Action.PERFORMING})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "index": index, "action_id": action_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	index = int(d["index"])
	action_id = int(d.get("action_id", 0))
