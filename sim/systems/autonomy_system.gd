class_name AutonomySystem
extends SimSystem
## Free will: once a minute, a person with free will who has been idle for IDLE_MINUTES
## (no queued action, no path, no direct input) picks something to do with Autonomy
## (D24) and queues it. Away from home, they first head home in their sleep window, and
## also when nothing is worth doing where they are (Routines, T-0036). ActionSystem walks them there and performs it. Runs last in the
## minute, after needs have changed.

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


## Sets a path home and emits &"heading_home"; false when already home or no way home.
static func _head_home(sim: Sim, person: Person) -> bool:
	var route := Routines.home_route(sim, person)
	if route.is_empty():
		return false
	person.path = route
	sim.emit_event(&"heading_home", {"person_id": person.id})
	return true
