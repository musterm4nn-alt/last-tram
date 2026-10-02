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
		var choice := Autonomy.choose(Autonomy.candidates(sim, person), sim.rng.stream("autonomy"))
		if choice.is_empty():
			if not _head_home(sim, person):
				person.autonomy_retry_tick = sim.clock.tick + RETRY_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
			continue
		var action := Action.new(String(choice["interaction_id"]), int(choice["object_id"]))
		action.id = sim.world.new_id()
		person.action_queue.append(action)
		sim.emit_event(&"autonomy_chose", {
			"person_id": person.id,
			"interaction_id": choice["interaction_id"],
			"target_id": choice["object_id"],
			"score": choice["score"],
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
	if Autonomy._restock_needed(sim, person) and _eat_out(sim, person, true):
		return true  # the fridge is running low: a grocery run while the Späti is open
	return false


## No food at home: queues the best errand that feeds them (groceries, the Imbiss, a Späti
## snack; Autonomy.errand) as a free-will choice would; with `groceries_only`, only a grocery
## run. False when none is open and reachable.
static func _eat_out(sim: Sim, person: Person, groceries_only: bool) -> bool:
	var best: Dictionary = {}
	for option: Dictionary in Autonomy.candidates(sim, person):
		var def := sim.content.interaction(String(option["interaction_id"]))
		if def == null or not def.advertise.has("hunger") or not Autonomy.errand(sim, person, def):
			continue
		if groceries_only and def.adds_groceries <= 0:
			continue
		if best.is_empty() or float(option["score"]) > float(best["score"]):
			best = option
	if best.is_empty():
		return false
	var action := Action.new(String(best["interaction_id"]), int(best["object_id"]))
	action.id = sim.world.new_id()
	person.action_queue.append(action)
	sim.emit_event(&"autonomy_chose", {"person_id": person.id, "interaction_id": best["interaction_id"], "target_id": best["object_id"], "score": best["score"]})
	return true


## Queues the interaction at home that advertises the most of `need_id` (on an object in the
## person's home that they may use now, with a free slot) and emits &"autonomy_chose" as a
## free-will choice would; false when there is none.
static func _go_home_for(sim: Sim, person: Person, need_id: String) -> bool:
	var best_def: InteractionDef = null
	var best_object := 0
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if lot == null or lot.id != person.home_lot_id:
			continue
		for def: InteractionDef in Interactions.offered_by(sim, obj.id):
			var gain := float(def.advertise.get(need_id, 0.0))
			if gain <= 0.0 or (best_def != null and gain <= float(best_def.advertise[need_id])):
				continue
			if Requirements.check(sim, person, def, obj.id).is_empty() and Autonomy._cells_to_free_slot(sim, person, obj, true) >= 0:
				best_def = def
				best_object = obj.id
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
