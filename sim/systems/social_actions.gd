class_name SocialActions
extends RefCounted
## ActionSystem's steps for person-targeted actions (T-0038; static, no state). The actor
## walks next to the target (re-routing when they move, for at most
## Conversations.ROUTE_LIMIT_MINUTES), then performs while both stay put and the target stays
## available. The outcome is rolled when it finishes (ActionSystem._progress).


static func step_queued(sim: Sim, person: Person, action: Action) -> void:
	if person.move_intent != Vector2.ZERO or not person.path.is_empty():
		return
	var target := sim.world.get_person(action.target_id)
	if not Conversations.available(sim, target):
		ActionSystem.fail(sim, person, action, "target_busy")
	elif Conversations.adjacent(person, target) or _remote(sim, action):
		start(sim, person, action, target)
	else:
		_route(sim, person, action, target)


static func step_routing(sim: Sim, person: Person, action: Action) -> void:
	if person.move_intent != Vector2.ZERO:
		ActionSystem.cancel(sim, person, action, "moved")
		return
	var target := sim.world.get_person(action.target_id)
	if not Conversations.available(sim, target):
		ActionSystem.fail(sim, person, action, "target_busy")
	elif sim.clock.tick - action.started_tick > Conversations.ROUTE_LIMIT_MINUTES * SimClock.STEPS_PER_GAME_MINUTE:
		ActionSystem.fail(sim, person, action, "target_left")
	elif person.path.is_empty():
		if Conversations.adjacent(person, target):
			start(sim, person, action, target)
		else:
			_route(sim, person, action, target)


static func step_performing(sim: Sim, person: Person, action: Action) -> void:
	if person.move_intent != Vector2.ZERO or not person.path.is_empty():
		ActionSystem.cancel(sim, person, action, "moved")
		return
	if not still_with_target(sim, person, action):
		ActionSystem.cancel(sim, person, action, "target_left")


## True while the target exists, is available and still stands next to the actor.
static func still_with_target(sim: Sim, person: Person, action: Action) -> bool:
	var target := sim.world.get_person(action.target_id)
	return Conversations.available(sim, target) and (_remote(sim, action) or Conversations.adjacent(person, target))


## True for remote interactions (phone calls): no walking, no standing together.
static func _remote(sim: Sim, action: Action) -> bool:
	var def := sim.content.interaction(action.interaction_id)
	return def != null and def.remote


## Starts performing next to `target`: both face each other (the target only when idle).
static func start(sim: Sim, person: Person, action: Action, target: Person) -> void:
	person.path.clear()
	action.state = Action.PERFORMING
	action.slot_index = 0
	action.started_tick = sim.clock.tick
	if not _remote(sim, action):
		Conversations.face(person, target)
		if target.action_queue.is_empty():
			Conversations.face(target, person)
	sim.emit_event(&"action_started", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id})


static func _route(sim: Sim, person: Person, action: Action, target: Person) -> void:
	var path := Conversations.route_to(sim, person, target)
	if path.is_empty():
		ActionSystem.fail(sim, person, action, "no_path")
		return
	if action.state != Action.ROUTING:
		action.state = Action.ROUTING
		action.slot_index = 0
		action.started_tick = sim.clock.tick  # when they set off (ROUTE_LIMIT_MINUTES)
		sim.emit_event(&"action_routing", {"person_id": person.id, "interaction_id": action.interaction_id, "target_id": action.target_id, "slot_index": 0})
	person.path = path
