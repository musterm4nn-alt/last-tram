class_name Interactions
extends RefCounted
## Static queries over interaction content and use slots (no state, not saved).


## Interactions the target object offers (via its tags), in content order.
## Empty when the object id is unknown.
static func offered_by(sim: Sim, object_id: int) -> Array[InteractionDef]:
	var out: Array[InteractionDef] = []
	var obj := sim.world.get_object(object_id)
	if obj == null:
		return out
	var def := sim.content.object_def(obj.def_id)
	if def == null:
		return out
	for candidate: InteractionDef in sim.content.interactions.values():
		for tag: String in candidate.object_tags:
			if tag in def.tags:
				out.append(candidate)
				break
	return out


## Person-targeted interactions `actor_id` may start with `target_id` (T-0038), in content
## order. Empty for an unknown person or for oneself.
static func offered_by_person(sim: Sim, actor_id: int, target_id: int) -> Array[InteractionDef]:
	var out: Array[InteractionDef] = []
	if actor_id == target_id or sim.world.get_person(target_id) == null:
		return out
	for candidate: InteractionDef in sim.content.interactions.values():
		if candidate.target == "person":
			out.append(candidate)
	return out


## Index of the use slot `person` stands on for this object, or -1.
## Compares full cells (including level), so standing under the slot is not enough.
static func slot_at_person(sim: Sim, person: Person, object_id: int) -> int:
	var obj := sim.world.get_object(object_id)
	if obj == null:
		return -1
	var here := person.cell()
	for index: int in obj.slot_count(sim.content):
		if obj.slot_cell(sim.content, index) == here:
			return index
	return -1


## True if another person's front action is routing to or performing on this slot.
## Slots are reserved implicitly: there is no extra saved state, so a save in
## mid-route keeps its reservation through the saved ROUTING action and path.
static func slot_taken(sim: Sim, object_id: int, slot_index: int, except_person_id: int) -> bool:
	for person: Person in sim.world.people.values():
		if person.id == except_person_id:
			continue
		if person.action_queue.is_empty():
			continue
		var front: Action = person.action_queue[0]
		if front.target_id != object_id or front.slot_index != slot_index:
			continue
		if front.state == Action.ROUTING or front.state == Action.PERFORMING:
			return true
	return false
