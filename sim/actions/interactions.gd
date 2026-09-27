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
