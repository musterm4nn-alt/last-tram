class_name CallCommand
extends Command
## The phone (T-0063): `person_id` calls `other_id`. Queues the remote "phone_call" at the
## front of the caller's queue; it starts at once if the other person is available (awake,
## not at work, not walking), else fails with "target_busy" ("No answer"). Ignored for unknown
## people, calling yourself, or a full queue.

var person_id: int = 0
var other_id: int = 0


func _init(p_person_id: int = 0, p_other_id: int = 0) -> void:
	person_id = p_person_id
	other_id = p_other_id


func type_id() -> String:
	return "call"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	var def := sim.content.interaction("phone_call")
	if person == null or def == null or other_id == person_id or sim.world.get_person(other_id) == null:
		return
	if person.action_queue.size() >= Person.MAX_QUEUE:
		return
	person.last_input_tick = sim.clock.tick
	ActionSystem.cancel_front(sim, person, "call")
	var action := Action.new(def.id, other_id)
	action.id = sim.world.new_id()
	person.action_queue.insert(0, action)
	sim.emit_event(&"action_queued", {"person_id": person_id, "interaction_id": def.id, "target_id": other_id})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "other_id": other_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	other_id = int(d["other_id"])
