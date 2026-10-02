class_name PlaceActions
extends RefCounted
## ActionSystem's steps for place actions (T-0068; static, no state): things done right where
## the person stands, on the lot that is the action's target (searching). No walking and no
## slot; moving off the lot or walking cancels it.


## One step: a QUEUED action starts once the person stands still on the lot (else it fails
## with "moved"); a PERFORMING one is cancelled by direct input or a path.
static func step(sim: Sim, person: Person, action: Action) -> void:
	if action.state == Action.PERFORMING:
		if person.move_intent != Vector2.ZERO or not person.path.is_empty():
			ActionSystem.cancel(sim, person, action, "moved")
		return
	if person.move_intent != Vector2.ZERO or not person.path.is_empty():
		return
	if not still_there(sim, person, action):
		ActionSystem.fail(sim, person, action, "moved")
		return
	var def := sim.content.interaction(action.interaction_id)
	var reason := Requirements.check(sim, person, def, action.target_id)
	if not reason.is_empty():
		ActionSystem.fail(sim, person, action, reason)
		return
	action.state = Action.PERFORMING
	action.slot_index = 0
	action.started_tick = sim.clock.tick
	sim.emit_event(&"action_started", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id})


## True while the person stands on the action's lot.
static func still_there(sim: Sim, person: Person, action: Action) -> bool:
	var lot := Lots.lot_at(sim, person.cell())
	return lot != null and lot.id == action.target_id


## A finished place action: a search looks for discoveries at the lot's place.
static func finish(sim: Sim, person: Person, action: Action) -> void:
	var lot: Lot = sim.world.lots.get(action.target_id)
	if lot != null and action.interaction_id == "search":
		Discoveries.search(sim, person, lot.place_id)
