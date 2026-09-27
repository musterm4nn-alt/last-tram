class_name ActionSystem
extends SimSystem
## Runs queued interactions: starts the front action once the person stands on
## one of the target's use slots (step), then applies its need rates every
## game minute until its end condition holds (on_minute). T-0007 replaces the
## not-at-slot failure with walking to the slot.


## Starts front actions whose person already stands on a use slot of the target.
## Otherwise the action fails and the queue moves on to the next one.
func step(sim: Sim) -> void:
	for person: Person in sim.world.people.values():
		if person.action_queue.is_empty():
			continue
		var action: Action = person.action_queue[0]
		if action.state != Action.QUEUED:
			continue
		var def := sim.content.interaction(action.interaction_id)
		var slot := Interactions.slot_at_person(sim, person, action.target_id)
		if def == null or slot < 0:
			person.action_queue.remove_at(0)
			var reason := "not_at_slot" if def != null else "unknown_interaction"
			sim.emit_event(&"action_failed", {"person_id": person.id, "interaction_id": action.interaction_id, "reason": reason})
			continue
		var obj := sim.world.get_object(action.target_id)
		action.state = Action.PERFORMING
		action.slot_index = slot
		action.started_tick = sim.clock.tick
		person.facing = Vector2(obj.slot_facing(sim.content, slot))
		sim.emit_event(&"action_started", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id})


## Applies need rates of performing front actions and finishes ended ones.
func on_minute(sim: Sim) -> void:
	for person: Person in sim.world.people.values():
		if person.action_queue.is_empty():
			continue
		var action: Action = person.action_queue[0]
		if action.state != Action.PERFORMING:
			continue
		var def := sim.content.interaction(action.interaction_id)
		if def == null:
			person.action_queue.remove_at(0)
			sim.emit_event(&"action_failed", {"person_id": person.id, "interaction_id": action.interaction_id, "reason": "unknown_interaction"})
			continue
		for need_id: String in def.need_rates:
			var before: float = float(person.needs.get(need_id, 0.0))
			person.needs[need_id] = clampf(before + float(def.need_rates[need_id]) / 60.0, 0.0, 100.0)
		action.minutes_done += 1
		if _has_ended(person, def, action):
			for need_id: String in def.finish_needs:
				var before: float = float(person.needs.get(need_id, 0.0))
				person.needs[need_id] = clampf(before + float(def.finish_needs[need_id]), 0.0, 100.0)
			person.action_queue.remove_at(0)
			sim.emit_event(&"action_finished", {"person_id": person.id, "interaction_id": action.interaction_id, "minutes": action.minutes_done})


## Fixed actions end after duration_minutes; until_need actions end once the
## need is full (but not before min_minutes) or at max_minutes.
static func _has_ended(person: Person, def: InteractionDef, action: Action) -> bool:
	if def.until_need.is_empty():
		return action.minutes_done >= def.duration_minutes
	if action.minutes_done >= def.max_minutes:
		return true
	return action.minutes_done >= def.min_minutes and float(person.needs.get(def.until_need, 0.0)) >= 100.0
