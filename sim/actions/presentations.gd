class_name Presentations
extends RefCounted
## Asks the view for a scene when an action with a presentation finishes (T-0043; static).
## The sim only emits &"scene_requested" {scene_id, actor_id, target_id, place_id}; showing it
## is the view's job, and nothing in the sim depends on it. A "once" presentation is
## remembered per person, so it is requested only the first time.


static func on_finish(sim: Sim, person: Person, action: Action, def: InteractionDef) -> void:
	var p := def.presentation
	if p == null or p.when != "finish":
		return
	if p.player_only and person.id != sim.world.player_id:
		return
	if p.day >= 0 and sim.clock.day() != p.day:
		return
	if p.once and person.scenes_requested.has(p.scene_id):
		return
	if p.chance < 1.0 and sim.rng.stream("scenes").randf() >= p.chance:
		return
	if p.once:
		person.scenes_requested.append(p.scene_id)
	var place := sim.content.place_at(person.cell())
	sim.emit_event(&"scene_requested", {
		"scene_id": p.scene_id,
		"actor_id": person.id,
		"target_id": action.target_id if sim.world.get_person(action.target_id) != null else 0,
		"place_id": place.id if place != null else "",
	})
