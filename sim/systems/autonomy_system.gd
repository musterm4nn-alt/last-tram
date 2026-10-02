class_name AutonomySystem
extends SimSystem
## Free will: once a minute, a person with free will who has been idle for IDLE_MINUTES
## (no queued action, no path, no direct input) picks something to do with Autonomy
## (D24) and queues it. First, someone low on hygiene or hunger sees to it at home (T-0060);
## away from home, they head home in their sleep window, and also when nothing is worth doing where they are (Routines,
## T-0036). ActionSystem walks them there and performs it. Runs last in the minute, after
## needs have changed.

## Game minutes without input before autonomy may act for a person.
const IDLE_MINUTES: int = 10
## After finding nothing worth doing, a person looks again only after this many minutes
## (most checks in a town of content people find nothing; T-0034).
const RETRY_MINUTES: int = 5


func on_minute(sim: Sim) -> void:
	var idle_ticks := IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	for person: Person in sim.world.people.values():
		if not person.free_will or not person.action_queue.is_empty() or not person.path.is_empty():
			continue
		if person.move_intent != Vector2.ZERO or sim.clock.tick - person.last_input_tick < idle_ticks:
			continue
		if sim.clock.tick < person.autonomy_retry_tick:
			continue
		if _see_to_home_needs(sim, person):
			continue
		if Routines.sleeping_time(sim, person) and _head_home(sim, person):
			continue
		var choice := Autonomy.decide(sim, person, sim.rng.stream("autonomy"))
		if choice == null:
			if not _head_home(sim, person):
				person.autonomy_retry_tick = sim.clock.tick + RETRY_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
			continue
		var action := Action.new(choice.interaction_id, choice.target_id)
		action.id = sim.world.new_id()
		person.action_queue.append(action)
		sim.emit_event(&"autonomy_chose", {
			"person_id": person.id,
			"interaction_id": choice.interaction_id,
			"target_id": choice.target_id,
			"score": choice.score,
		})


## Needs that home looks after (T-0060): a person low on one (Routines.home_needs) goes and
## does the best thing for it at home. A wash with no free shower sends them home anyway; a
## meal with no food at home is left to free will's errands (shopping, eating out).
static func _see_to_home_needs(sim: Sim, person: Person) -> bool:
	for need_id: String in Routines.home_needs(sim, person):
		if _go_home_for(sim, person, need_id):
			return true
		if need_id == "hygiene" and _head_home(sim, person):
			return true
		if need_id == "hunger" and _eat_out(sim, person, false):
			return true
	if Autonomy.restock_needed(sim, person) and _eat_out(sim, person, true):
		return true  # the fridge is running low: a grocery run while the Späti is open
	return false


## No food at home: queues the best errand that feeds them (groceries, the Imbiss, a Späti
## snack; Autonomy.errand) as a free-will choice would; with `groceries_only`, only a grocery
## run. False when none is open and reachable.
static func _eat_out(sim: Sim, person: Person, groceries_only: bool) -> bool:
	var best: AutonomyOption = null
	for option: AutonomyOption in Autonomy.candidates(sim, person):
		var def := sim.content.interaction(option.interaction_id)
		if def == null or not def.advertise.has("hunger") or not Autonomy.errand(sim, person, def):
			continue
		if groceries_only and def.adds_groceries <= 0:
			continue
		if best == null or option.score > best.score:
			best = option
	if best == null:
		return false
	var action := Action.new(best.interaction_id, best.target_id)
	action.id = sim.world.new_id()
	person.action_queue.append(action)
	sim.emit_event(&"autonomy_chose", {"person_id": person.id, "interaction_id": best.interaction_id, "target_id": best.target_id, "score": best.score})
	return true


## Queues the interaction at home that advertises the most of `need_id` (on an object in the
## person's home that they may use now, with a free slot) and emits &"autonomy_chose" as a
## free-will choice would; false when there is none.
static func _go_home_for(sim: Sim, person: Person, need_id: String) -> bool:
	# The best gain wins, the first object (by id) on ties: try them in that order and take the
	# first that is allowed and reachable, so only the winner's walk is worked out (T-0078).
	var offers: Array[Array] = []
	for id: int in sim.world.objects_on_lot(person.home_lot_id):
		var offered := Interactions.offered_by(sim, id)
		for index: int in offered.size():
			var gain := float(offered[index].advertise.get(need_id, 0.0))
			if gain > 0.0:
				offers.append([gain, id, index, offered[index]])
	offers.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] > b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	var best_def: InteractionDef = null
	var best_object := 0
	for offer: Array in offers:
		var obj: WorldObject = sim.world.objects[offer[1]]
		if Requirements.check(sim, person, offer[3], obj.id).is_empty() and Autonomy.cells_to_free_slot(sim, person, obj, true) >= 0:
			best_def = offer[3]
			best_object = obj.id
			break
	if best_def == null:
		return false
	var action := Action.new(best_def.id, best_object)
	action.id = sim.world.new_id()
	person.action_queue.append(action)
	sim.emit_event(&"autonomy_chose", {"person_id": person.id, "interaction_id": best_def.id, "target_id": best_object, "score": 0.0})
	return true


## Sets a path home and emits &"heading_home"; false when already home or no way home.
static func _head_home(sim: Sim, person: Person) -> bool:
	var route := Routines.home_route(sim, person)
	if route.is_empty():
		return false
	person.path = route
	sim.emit_event(&"heading_home", {"person_id": person.id})
	return true
