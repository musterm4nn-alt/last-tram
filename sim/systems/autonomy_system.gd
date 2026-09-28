class_name AutonomySystem
extends SimSystem
## Free will: once a minute, a person with free will who has been idle for IDLE_MINUTES
## (no queued action, no path, no direct input) picks something to do with Autonomy
## (D24) and queues it. ActionSystem walks them there and performs it. Runs last in the
## minute, after needs have changed.

## Game minutes without input before autonomy may act for a person.
const IDLE_MINUTES: int = 10


func on_minute(sim: Sim) -> void:
	var idle_ticks := IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	for person: Person in sim.world.people.values():
		if not person.free_will or not person.action_queue.is_empty() or not person.path.is_empty():
			continue
		if person.move_intent != Vector2.ZERO or sim.clock.tick - person.last_input_tick < idle_ticks:
			continue
		var choice := Autonomy.choose(Autonomy.candidates(sim, person), sim.rng.stream("autonomy"))
		if choice.is_empty():
			continue
		person.action_queue.append(Action.new(String(choice["interaction_id"]), int(choice["object_id"])))
		sim.emit_event(&"autonomy_chose", {
			"person_id": person.id,
			"interaction_id": choice["interaction_id"],
			"target_id": choice["object_id"],
			"score": choice["score"],
		})
