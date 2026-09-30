class_name QueueInteractionCommand
extends Command
## Queues an interaction on an object for a person (the front of the queue is
## current). Ignored unless the person and the object exist, the object offers
## the interaction, and the queue has room. ActionSystem then walks the person
## to a free use slot of the object and starts it there.

var person_id: int = 0
var interaction_id: String = ""
var target_id: int = 0


func _init(p_person_id: int = 0, p_interaction_id: String = "", p_target_id: int = 0) -> void:
	person_id = p_person_id
	interaction_id = p_interaction_id
	target_id = p_target_id


func type_id() -> String:
	return "queue_interaction"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.last_input_tick = sim.clock.tick
	if sim.world.get_object(target_id) == null:
		return
	if sim.content.interaction(interaction_id) == null:
		return
	if person.action_queue.size() >= Person.MAX_QUEUE:
		return
	var offered := false
	for candidate: InteractionDef in Interactions.offered_by(sim, target_id):
		if candidate.id == interaction_id:
			offered = true
			break
	if not offered:
		return
	var action := Action.new(interaction_id, target_id)
	action.id = sim.world.new_id()
	person.action_queue.append(action)
	sim.emit_event(&"action_queued", {"person_id": person_id, "interaction_id": interaction_id, "target_id": target_id})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "interaction_id": interaction_id, "target_id": target_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	interaction_id = String(d["interaction_id"])
	target_id = int(d["target_id"])
