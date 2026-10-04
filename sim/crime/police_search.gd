class_name PoliceSearch
extends RefCounted
## An officer who lost sight of their suspect (T-0095, D36): they go to where they last saw
## them, search the cells around there on foot for PoliceRules.search_minutes, and then give
## up. The suspect's crimes are then "lost": they cool off after lost_heat_hours, and nobody
## is sent after them unless an officer sees them again or a new crime is reported.

## Random cells tried when picking the next place to look.
const TRIES: int = 8


## A step of an officer who can't see the suspect: walk on to last_seen; once there (or with
## no way there) start searching; while searching, look somewhere else nearby whenever they
## have arrived; at search_until, give up.
static func step(sim: Sim, task: PoliceTask, officer: Person) -> void:
	if task.search_until < 0:
		if officer.path.is_empty():
			_start(sim, task, officer)
		return
	if sim.clock.tick >= task.search_until:
		give_up(sim, task, officer)
	elif officer.path.is_empty():
		_look_around(sim, task, officer)


## The officer sees the suspect again: the search is over, they run after them.
static func found(sim: Sim, task: PoliceTask, officer: Person) -> void:
	task.search_until = -1
	officer.running = true


## The officer gives up: the suspect's counting incidents are lost (lost_tick = now), the
## officer walks back to the desk, and &"police_gave_up" {officer_id, person_id} goes out.
static func give_up(sim: Sim, task: PoliceTask, officer: Person) -> void:
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == task.target_id and incident.lost_tick < 0 and Police.counts(sim, incident):
			incident.lost_tick = sim.clock.tick
	Police.go_back(sim, officer, task)
	sim.emit_event(&"police_gave_up", {"officer_id": officer.id, "person_id": task.target_id})


## A returning officer sees a suspect who is still wanted: the suspect's lost incidents are
## sought again, and the officer runs after them. Emits &"police_spotted" {officer_id,
## person_id}.
static func spotted(sim: Sim, task: PoliceTask, officer: Person, suspect: Person) -> void:
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == suspect.id and incident.lost_tick >= 0 and Police.counts(sim, incident):
			incident.lost_tick = -1
	task.returning = false
	task.search_until = -1
	task.last_seen = suspect.cell()
	officer.running = true
	Police.head_to(sim, officer, task.last_seen)
	sim.emit_event(&"police_spotted", {"officer_id": officer.id, "person_id": suspect.id})


## The officer arrived where they last saw the suspect: the search starts (walking).
## Emits &"police_searching" {officer_id, person_id}.
static func _start(sim: Sim, task: PoliceTask, officer: Person) -> void:
	task.search_until = sim.clock.tick + SimClock.ticks_for(0, 0, sim.content.police_rules.search_minutes)
	officer.running = false
	sim.emit_event(&"police_searching", {"officer_id": officer.id, "person_id": task.target_id})
	_look_around(sim, task, officer)


## Sends the officer to a random reachable walkable cell within search_radius of last_seen,
## on its floor (TRIES draws from the "police" stream; they stay put if none works).
static func _look_around(sim: Sim, task: PoliceTask, officer: Person) -> void:
	var rng := sim.rng.stream("police")
	var radius := sim.content.police_rules.search_radius
	for i: int in TRIES:
		var cell := task.last_seen + Vector3i(rng.randi_range(-radius, radius), rng.randi_range(-radius, radius), 0)
		if cell == officer.cell() or not sim.world.grid.is_walkable(cell):
			continue
		var path := sim.nav.find_path(officer.cell(), cell)
		if not path.is_empty():
			officer.path = path
			return
