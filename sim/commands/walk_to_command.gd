class_name WalkToCommand
extends Command
## Sends a person to a cell along a pathfound route. The path is followed by
## MovementSystem; direct WASD input (a non-zero move intent) overrides it. A walk with no
## way there isn't input (T-0077). The walk itself is input until it ends: free will waits
## AutonomySystem.IDLE_MINUTES from the expected arrival (autonomy_retry_tick), so a long walk
## doesn't end with free will sending the person straight back home (T-0076).

var person_id: int = 0
var target: Vector3i = Vector3i.ZERO


func _init(p_person_id: int = 0, p_target: Vector3i = Vector3i.ZERO) -> void:
	person_id = p_person_id
	target = p_target


func type_id() -> String:
	return "walk_to"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	if target == person.cell():
		person.last_input_tick = sim.clock.tick
		ActionSystem.cancel_front(sim, person, "walked")
		person.path.clear()
		person.move_intent = Vector2.ZERO
		return
	var path := sim.nav.find_path(person.cell(), target)
	if path.is_empty():
		sim.emit_event(&"path_failed", {"person_id": person_id, "target": Ser.cell(target)})
	else:
		person.last_input_tick = sim.clock.tick
		ActionSystem.cancel_front(sim, person, "walked")
		person.path = path
		person.move_intent = Vector2.ZERO
		var arrival := sim.clock.tick + walk_ticks(person, path)
		person.autonomy_retry_tick = maxi(person.autonomy_retry_tick, arrival + AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE)


## Steps the walk along `path` takes at the person's walking speed (rounded up; a stair hop
## counts as one cell, as in MovementSystem.follow_path).
static func walk_ticks(person: Person, path: Array[Vector3i]) -> int:
	var cells := 0.0
	var at := person.pos
	var level := person.level
	for waypoint: Vector3i in path:
		var centre := Vector2(waypoint.x + 0.5, waypoint.y + 0.5)
		cells += 1.0 if waypoint.z != level else at.distance_to(centre)
		at = centre
		level = waypoint.z
	return ceili(cells / person.walk_speed * SimClock.STEPS_PER_GAME_MINUTE)


func to_dict() -> Dictionary:
	return {"person_id": person_id, "target": Ser.cell(target)}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	target = Ser.to_cell(d["target"])
