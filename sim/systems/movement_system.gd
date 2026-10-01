class_name MovementSystem
extends SimSystem
## Moves people by their move_intent (direct control), or else along their path (set by
## WalkToCommand), sliding along walls, at Person.move_speed() (faster while running).
## Collision: a person is a box of half-size Person.RADIUS that may only overlap walkable
## cells. X and Y are resolved separately, so walking diagonally into a wall slides along it.

## Keeps people a hair away from walls so they never count as touching them.
const EPSILON: float = 0.001


func step(sim: Sim) -> void:
	var cells_per_step := 1.0 / SimClock.STEPS_PER_GAME_MINUTE
	for person: Person in sim.world.people.values():
		person.prev_pos = person.pos
		if person.move_intent != Vector2.ZERO:
			var direction := person.move_intent.limit_length(1.0)
			person.facing = _cardinal(direction)
			move_person(sim.world.grid, person, direction * person.move_speed() * cells_per_step)
		elif not person.path.is_empty():
			follow_path(sim, person, person.move_speed() * cells_per_step)


## Walks `person` along their path, covering up to `budget` cells this step.
## Leftover distance carries on to the next waypoint in the same step.
static func follow_path(sim: Sim, person: Person, budget: float) -> void:
	while budget > 0.0 and not person.path.is_empty():
		var next: Vector3i = person.path[0]
		if not sim.world.grid.is_walkable(next):
			# Something now blocks the route (e.g. an object was placed).
			person.path.clear()
			sim.emit_event(&"path_blocked", {"person_id": person.id})
			return
		var centre := Vector2(next.x + 0.5, next.y + 0.5)
		var to_centre := centre - person.pos
		var dist := to_centre.length()
		if dist > 0.0:
			person.facing = _cardinal(to_centre)
		if dist <= budget:
			# A cell centre on a walkable cell is always a legal spot.
			person.pos = centre
			person.path.remove_at(0)
			budget -= dist
		else:
			move_person(sim.world.grid, person, to_centre / dist * budget)
			budget = 0.0


## Moves `person` by `delta` cells, stopping at non-walkable cells.
## `delta` must be shorter than one cell per axis (true for any sane speed).
static func move_person(grid: WorldGrid, person: Person, delta: Vector2) -> void:
	var r := Person.RADIUS
	if delta.x != 0.0:
		var x := person.pos.x + delta.x
		if is_box_blocked(grid, person.level, Vector2(x, person.pos.y)):
			if delta.x > 0.0:
				x = floorf(x + r) - r - EPSILON
			else:
				x = floorf(x - r) + 1.0 + r + EPSILON
			if is_box_blocked(grid, person.level, Vector2(x, person.pos.y)):
				x = person.pos.x
		person.pos.x = x
	if delta.y != 0.0:
		var y := person.pos.y + delta.y
		if is_box_blocked(grid, person.level, Vector2(person.pos.x, y)):
			if delta.y > 0.0:
				y = floorf(y + r) - r - EPSILON
			else:
				y = floorf(y - r) + 1.0 + r + EPSILON
			if is_box_blocked(grid, person.level, Vector2(person.pos.x, y)):
				y = person.pos.y
		person.pos.y = y


## True if a person-sized box centred at `center` overlaps any non-walkable cell.
static func is_box_blocked(grid: WorldGrid, level: int, center: Vector2) -> bool:
	var r := Person.RADIUS
	for y: int in range(floori(center.y - r), floori(center.y + r) + 1):
		for x: int in range(floori(center.x - r), floori(center.x + r) + 1):
			if not grid.is_walkable(Vector3i(x, y, level)):
				return true
	return false


static func _cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP
