class_name QueueInteractionCommand
extends Command
## Queues an interaction for a person (the front of the queue is current), on an object or,
## for person-targeted interactions, on another person (T-0038). Ignored unless the person
## and the target exist, the target offers the interaction, and the queue has room. Refused,
## with &"action_refused" {person_id, interaction_id, target_id, reason}, when the person may
## not do it now (Requirements: closed, not their home, can't afford...). Only an accepted
## command counts as input (last_input_tick, T-0077): a refused click doesn't hold free will back.
## ActionSystem then walks the person to a free use slot (or next to the other person) and
## starts it there.

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
	var def := sim.content.interaction(interaction_id)
	if def == null:
		return
	if person.action_queue.size() >= Person.MAX_QUEUE:
		return
	var options := Interactions.offered_by(sim, target_id)
	if def.target == "person":
		options = Interactions.offered_by_person(sim, person_id, target_id)
	elif def.target == "place":
		options = Interactions.offered_by_place(sim, person, target_id)
	var offered := false
	for candidate: InteractionDef in options:
		if candidate.id == interaction_id:
			offered = true
			break
	if not offered:
		return
	var reason := Requirements.check(sim, person, def, target_id)
	if not reason.is_empty():
		sim.emit_event(&"action_refused", {"person_id": person_id, "interaction_id": interaction_id, "target_id": target_id, "reason": reason})
		return
	person.last_input_tick = sim.clock.tick
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
