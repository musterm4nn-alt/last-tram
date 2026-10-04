class_name Witnesses
extends RefCounted
## Who sees a crime (T-0092, docs/design/crime-and-police.md "Being noticed"): people on the
## same floor within sight range (shorter at night), awake, not away in a rabbit hole, and
## with nothing that blocks sight (walls, doors, hedges) on the line between. Each one
## remembers it ("saw_crime" about the perpetrator) and is listed on the incident.

const MEMORY_KIND: String = "saw_crime"


## Finds the witnesses of `incident`, records them on it and gives each the memory. People in
## `unaware` don't count (a victim who didn't notice, T-0096).
static func record(sim: Sim, incident: Incident, unaware: Array[int] = []) -> void:
	var rules := sim.content.witness_rules
	var found := PackedInt32Array()
	for id: int in find(sim, incident.cell, incident.perpetrator_id):
		if not unaware.has(id):
			found.append(id)
	incident.witnesses = found
	for id: int in found:
		var witness := sim.world.get_person(id)
		Social.remember(sim, witness, MEMORY_KIND, [incident.perpetrator_id] as Array[int], rules.memory_valence, rules.memory_salience)
		sim.emit_event(&"crime_witnessed", {"incident_id": incident.id, "person_id": id})


## The ids (ascending) of the people who can see `cell` now, other than `except_id`.
static func find(sim: Sim, cell: Vector3i, except_id: int) -> PackedInt32Array:
	var range_cells := sight_range(sim)
	var out := PackedInt32Array()
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		if id == except_id:
			continue
		var person := sim.world.get_person(id)
		var at := person.cell()
		if at.z != cell.z or maxi(absi(at.x - cell.x), absi(at.y - cell.y)) > range_cells:
			continue
		if asleep(sim, person) or Jobs.hidden(sim, person):
			continue
		if clear_line(sim, at, cell):
			out.append(id)
	return out


## How far people see now, in cells: day_range, or night_range in the night hours.
static func sight_range(sim: Sim) -> int:
	var rules := sim.content.witness_rules
	var hour := sim.clock.hour()
	var night := hour >= rules.night_from or hour < rules.night_until
	return rules.night_range if night else rules.day_range


## True when nothing between `from` and `to` (same floor) blocks sight. The end cells don't
## count (a clerk behind a counter still sees the customer).
static func clear_line(sim: Sim, from: Vector3i, to: Vector3i) -> bool:
	var grid := sim.world.grid
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx + dy
	var x := from.x
	var y := from.y
	while not (x == to.x and y == to.y):
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
		if x == to.x and y == to.y:
			break
		var c := Vector3i(x, y, from.z)
		if grid.terrain_def_at(c).blocks_sight:
			return false
		for object_id: int in sim.world.objects_at(c):
			var def := sim.content.object_def(sim.world.get_object(object_id).def_id)
			if def != null and def.blocks_sight:
				return false
	return true


## True while the person is sleeping.
static func asleep(sim: Sim, person: Person) -> bool:
	if person.action_queue.is_empty() or person.action_queue[0].state != Action.PERFORMING:
		return false
	var def := sim.content.interaction(person.action_queue[0].interaction_id)
	return def != null and def.routine == "sleep"
