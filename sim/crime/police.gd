class_name Police
extends RefCounted
## Reports and the wanted level (T-0093, docs/design/crime-and-police.md "Police"). Witnesses
## may call the police; reported crimes give the perpetrator a wanted level 0-5 that cools
## off after PoliceRules.heat_hours. Officers respond (T-0094): PoliceSystem dispatches the
## nearest on-duty officer to a wanted person, who chases them while in sight and arrests
## them when close (a fine, the incidents closed, a criminal record).

const MAX_LEVEL: int = 5
## The job whose holders answer calls while they work.
const JOB_ID: String = "police_officer"


## Each witness of `incident` (ascending id) may call the police; the first one who does is
## the reporter. One draw per witness from the "crime" stream.
static func maybe_report(sim: Sim, incident: Incident) -> void:
	var crime := sim.content.crime(incident.crime_id)
	if crime == null:
		return
	var rng := sim.rng.stream("crime")
	for id: int in incident.witnesses:
		var roll := rng.randf()
		if incident.reported_by != 0:
			continue
		if roll < report_chance(sim, sim.world.get_person(id), incident.perpetrator_id, crime.severity):
			incident.reported_by = id
			incident.reported_tick = sim.clock.tick
			sim.emit_event(&"crime_reported", {"incident_id": incident.id, "reporter_id": id, "person_id": incident.perpetrator_id})


## How likely `witness` is to report a crime of `severity` by `perpetrator_id`.
static func report_chance(sim: Sim, witness: Person, perpetrator_id: int, severity: int) -> float:
	var rules := sim.content.police_rules
	var chance := minf(rules.report_base + rules.report_per_severity * severity, 0.95)
	var r := Social.relationship(witness, perpetrator_id)
	if r != null and r.friendship >= rules.friend_at:
		chance *= rules.friend_report_factor
	return chance


## How hard the police are looking for `person_id` now: 0 (not at all) to MAX_LEVEL.
static func wanted_level(sim: Sim, person_id: int) -> int:
	var rules := sim.content.police_rules
	var window := SimClock.ticks_for(0, rules.heat_hours)
	var total := 0
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id != person_id or incident.reported_by == 0 or incident.closed_tick >= 0:
			continue
		if sim.clock.tick - incident.reported_tick >= window:
			continue
		var crime := sim.content.crime(incident.crime_id)
		total += crime.severity if crime != null else 0
	return mini(ceili(float(total) / rules.severity_per_level), MAX_LEVEL)


## The ids (ascending) of everyone with a wanted level of 1 or more.
static func wanted_people(sim: Sim) -> Array[int]:
	var out: Array[int] = []
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if not out.has(incident.perpetrator_id) and _counts(sim, incident):
			out.append(incident.perpetrator_id)
	out.sort()
	return out


## The cell of `person_id`'s latest open reported incident (where the police start looking).
static func last_reported_cell(sim: Sim, person_id: int) -> Vector3i:
	var best: Incident = null
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == person_id and _counts(sim, incident) \
				and (best == null or incident.reported_tick >= best.reported_tick):
			best = incident
	return best.cell if best != null else Vector3i.ZERO


## True while an incident counts towards its perpetrator's wanted level: reported, not closed,
## within the last heat_hours, and of a crime the content still has.
static func _counts(sim: Sim, incident: Incident) -> bool:
	if incident.reported_by == 0 or incident.closed_tick >= 0 or sim.content.crime(incident.crime_id) == null:
		return false
	return sim.clock.tick - incident.reported_tick < SimClock.ticks_for(0, sim.content.police_rules.heat_hours)


## True while `person` works a police shift (at the desk or out on a call).
static func on_duty(sim: Sim, person: Person) -> bool:
	return person != null and person.job != null and person.job.job_id == JOB_ID and Jobs.working(sim, person)


## True while `person` is an officer on a call (chasing someone or walking back).
static func on_call(sim: Sim, person: Person) -> bool:
	return person != null and sim.world.police_tasks.has(person.id)


## True if an officer is after `person_id` now (not just walking back).
static func pursued(sim: Sim, person_id: int) -> bool:
	for officer_id: int in sim.world.police_tasks:
		var task: PoliceTask = sim.world.police_tasks[officer_id]
		if task.target_id == person_id and not task.returning:
			return true
	return false


## Sends the nearest free on-duty officer (Manhattan distance + 10 per floor, ties to the lower
## id; an officer walking back counts as free) after `suspect`, heading for their latest
## reported crime, running. Emits &"police_dispatched" {officer_id, person_id}. Null when no
## officer is free.
static func dispatch(sim: Sim, suspect: Person) -> PoliceTask:
	var goal := last_reported_cell(sim, suspect.id)
	var best: Person = null
	var best_distance := 0
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		var officer := sim.world.get_person(id)
		if id == suspect.id or not on_duty(sim, officer):
			continue
		var busy: PoliceTask = sim.world.police_tasks.get(id)
		if busy != null and not busy.returning:
			continue
		var at := officer.cell()
		var distance := absi(at.x - goal.x) + absi(at.y - goal.y) + 10 * absi(at.z - goal.z)
		if best == null or distance < best_distance:
			best = officer
			best_distance = distance
	if best == null:
		return null
	var task := PoliceTask.new()
	task.officer_id = best.id
	task.target_id = suspect.id
	task.last_seen = goal
	sim.world.police_tasks[best.id] = task
	best.running = true
	_head_to(sim, best, goal)
	sim.emit_event(&"police_dispatched", {"officer_id": best.id, "person_id": suspect.id})
	return task


## True if `officer` can see `suspect` now: the same floor, within sight range, nothing in
## the way, and the suspect not out of sight at work.
static func can_see(sim: Sim, officer: Person, suspect: Person) -> bool:
	if officer.level != suspect.level or Jobs.hidden(sim, suspect):
		return false
	var a := officer.cell()
	var b := suspect.cell()
	if maxi(absi(a.x - b.x), absi(a.y - b.y)) > Witnesses.sight_range(sim):
		return false
	return Witnesses.clear_line(sim, a, b)


## One step of a call: an officer who sees the suspect heads for where they are now and
## arrests them within arrest_range; one who doesn't keeps going to where they last saw them
## (and waits there). An officer walking back ends the call at the desk.
static func chase(sim: Sim, task: PoliceTask) -> void:
	var officer := sim.world.get_person(task.officer_id)
	var suspect := sim.world.get_person(task.target_id)
	if officer == null or suspect == null:
		end_call(sim, task)
		return
	if task.returning:
		if officer.path.is_empty():
			var desk := desk_cell(sim, officer)
			if officer.cell() != desk:
				_head_to(sim, officer, desk)
			if officer.path.is_empty():
				end_call(sim, task)  # at the desk (or no way back)
		return
	if not can_see(sim, officer, suspect):
		return
	if officer.pos.distance_to(suspect.pos) <= sim.content.police_rules.arrest_range:
		arrest(sim, officer, suspect)
		return
	var cell := suspect.cell()
	if cell != task.last_seen or (officer.path.is_empty() and officer.cell() != cell):
		task.last_seen = cell
		_head_to(sim, officer, cell)


## The fine for `person_id`'s open reported crimes: severity × fine_per_severity each.
static func fine_for(sim: Sim, person_id: int) -> int:
	var total := 0
	for incident: Incident in _charges(sim, person_id):
		total += sim.content.crime(incident.crime_id).severity * sim.content.police_rules.fine_per_severity
	return total


## `officer` arrests `suspect`: the fine (Money.fine), the open reported incidents closed, a
## criminal record, the suspect stopped (front action cancelled as "arrested"; an NPC's
## plans dropped) and the officer walking back. Emits &"arrested" {person_id, officer_id,
## fine, incidents}. Returns the fine.
static func arrest(sim: Sim, officer: Person, suspect: Person) -> int:
	var charges := _charges(sim, suspect.id)
	var fine := fine_for(sim, suspect.id)
	var ids: Array[int] = []
	for incident: Incident in charges:
		incident.closed_tick = sim.clock.tick
		ids.append(incident.id)
	if fine > 0:
		Money.fine(sim, suspect, fine, charges[0].crime_id)
	suspect.record = true
	ActionSystem.cancel_front(sim, suspect, "arrested")
	if suspect.id != sim.world.player_id:
		suspect.action_queue.clear()
	suspect.path.clear()
	suspect.move_intent = Vector2.ZERO
	suspect.running = false
	var task: PoliceTask = sim.world.police_tasks.get(officer.id)
	if task != null:
		go_back(sim, officer, task)
	sim.emit_event(&"arrested", {"person_id": suspect.id, "officer_id": officer.id, "fine": fine, "incidents": ids})
	return fine


## The officer stops chasing and walks back to the desk (the call ends there).
static func go_back(sim: Sim, officer: Person, task: PoliceTask) -> void:
	task.returning = true
	officer.running = false
	_head_to(sim, officer, desk_cell(sim, officer))


## Ends the call: the officer stops where they are.
static func end_call(sim: Sim, task: PoliceTask) -> void:
	sim.world.police_tasks.erase(task.officer_id)
	var officer := sim.world.get_person(task.officer_id)
	if officer != null:
		officer.running = false
		officer.path.clear()


## The cell of the slot where the officer works their shift (their own cell when not working).
static func desk_cell(sim: Sim, officer: Person) -> Vector3i:
	if not Jobs.working(sim, officer):
		return officer.cell()
	var action: Action = officer.action_queue[0]
	var obj := sim.world.get_object(action.target_id)
	if obj == null or action.slot_index < 0 or action.slot_index >= obj.slot_count(sim.content):
		return officer.cell()
	return obj.slot_cell(sim.content, action.slot_index)


## `person_id`'s open reported incidents (what an arrest charges them with), oldest first.
static func _charges(sim: Sim, person_id: int) -> Array[Incident]:
	var out: Array[Incident] = []
	for incident: Incident in Crimes.committed_by(sim, person_id):
		if incident.reported_by != 0 and incident.closed_tick < 0 and sim.content.crime(incident.crime_id) != null:
			out.append(incident)
	return out


## Sets the officer's path to `cell` (none when already there or there is no way).
static func _head_to(sim: Sim, officer: Person, cell: Vector3i) -> void:
	if officer.cell() == cell:
		officer.path.clear()
	else:
		officer.path = sim.nav.find_path(officer.cell(), cell)
