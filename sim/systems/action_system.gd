class_name ActionSystem
extends SimSystem
## Runs queued interactions: QUEUED front actions start at once on a free slot or
## pick a walking route there (QUEUED -> ROUTING), ROUTING ones start on arrival
## (ROUTING -> PERFORMING) and re-route when their path is blocked, then
## PERFORMING ones apply need rates every game minute until their end condition
## holds (on_minute). Non-zero direct (WASD) input cancels routing or performing.


## Steps every front action once: QUEUED ones start or route, ROUTING ones
## arrive, re-route or cancel, PERFORMING ones cancel on direct input.
func step(sim: Sim) -> void:
	for person: Person in sim.world.people.values():
		if person.action_queue.is_empty():
			continue
		var action: Action = person.action_queue[0]
		if action.state == Action.QUEUED:
			_step_queued(sim, person, action)
		elif action.state == Action.ROUTING:
			_step_routing(sim, person, action)
		elif action.state == Action.PERFORMING:
			if person.move_intent != Vector2.ZERO:
				_cancel(sim, person, action, "moved")


## A QUEUED front action starts at once when its person already stands on a free
## slot of the target, and otherwise picks a route to walk there.
static func _step_queued(sim: Sim, person: Person, action: Action) -> void:
	if sim.content.interaction(action.interaction_id) == null:
		_fail(sim, person, action, "unknown_interaction")
		return
	var slot := Interactions.slot_at_person(sim, person, action.target_id)
	if slot >= 0 and not Interactions.slot_taken(sim, action.target_id, slot, person.id):
		_start_performing(sim, person, action, slot)
	else:
		_choose_route(sim, person, action)


## A ROUTING front action, checked in order: direct input cancels first, arrival
## starts performing, and an emptied path (e.g. after path_blocked) picks a new
## route. A non-empty path keeps walking (MovementSystem follows it this step).
static func _step_routing(sim: Sim, person: Person, action: Action) -> void:
	if person.move_intent != Vector2.ZERO:
		_cancel(sim, person, action, "moved")
		return
	var obj := sim.world.get_object(action.target_id)
	var valid := obj != null and action.slot_index >= 0 and action.slot_index < obj.slot_count(sim.content)
	if not valid:
		_choose_route(sim, person, action)
		return
	var cell := obj.slot_cell(sim.content, action.slot_index)
	if person.path.is_empty() and person.cell() == cell:
		_start_performing(sim, person, action, action.slot_index)
		return
	if person.path.is_empty():
		_choose_route(sim, person, action)


## Picks the nearest reachable free slot for the front action: sets the path,
## marks it ROUTING and emits action_routing. Fails with no_free_slot when every
## slot is taken, or no_path when no free slot can be walked to.
static func _choose_route(sim: Sim, person: Person, action: Action) -> void:
	if sim.content.interaction(action.interaction_id) == null:
		_fail(sim, person, action, "unknown_interaction")
		return
	var obj := sim.world.get_object(action.target_id)
	var count := obj.slot_count(sim.content) if obj != null else 0
	var free: Array[int] = []
	for index: int in count:
		if not Interactions.slot_taken(sim, action.target_id, index, person.id):
			free.append(index)
	if free.is_empty():
		_fail(sim, person, action, "no_free_slot")
		return
	var here := person.cell()
	var best := -1
	var best_path: Array[Vector3i] = []
	for index: int in free:
		var cell := obj.slot_cell(sim.content, index)
		if not sim.world.grid.is_walkable(cell):
			continue
		if cell == here:
			best = index
			best_path = []
			break
		var path := sim.nav.find_path(here, cell)
		if path.is_empty():
			continue
		if best < 0 or path.size() < best_path.size():
			best = index
			best_path = path
	if best < 0:
		_fail(sim, person, action, "no_path")
		return
	action.slot_index = best
	person.path = best_path
	action.state = Action.ROUTING
	sim.emit_event(&"action_routing", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id, "slot_index": best})


## Snaps the person onto the slot cell centre, then marks the front action
## PERFORMING with its slot, start tick and facing, emitting action_started.
static func _start_performing(sim: Sim, person: Person, action: Action, slot: int) -> void:
	var obj := sim.world.get_object(action.target_id)
	if obj == null:
		_fail(sim, person, action, "no_path")
		return
	var cell := obj.slot_cell(sim.content, slot)
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	action.state = Action.PERFORMING
	action.slot_index = slot
	action.started_tick = sim.clock.tick
	person.facing = Vector2(obj.slot_facing(sim.content, slot))
	sim.emit_event(&"action_started", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id})


## Pops the front action as failed. A ROUTING action also drops its path.
static func _fail(sim: Sim, person: Person, action: Action, reason: String) -> void:
	person.action_queue.remove_at(0)
	if action.state == Action.ROUTING:
		person.path.clear()
	sim.emit_event(&"action_failed", {"person_id": person.id, "interaction_id": action.interaction_id, "reason": reason})


## Pops the front action as cancelled (direct input took over): the same shape
## CancelActionCommand emits. A ROUTING action also drops its path.
static func _cancel(sim: Sim, person: Person, action: Action, reason: String) -> void:
	person.action_queue.remove_at(0)
	if action.state == Action.ROUTING:
		person.path.clear()
	sim.emit_event(&"action_cancelled", {"person_id": person.id, "interaction_id": action.interaction_id, "reason": reason})


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
