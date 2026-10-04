class_name Police
extends RefCounted
## Reports and the wanted level (T-0093, docs/design/crime-and-police.md "Police"). Witnesses
## may call the police; reported crimes give the perpetrator a wanted level 0-5 that cools
## off after PoliceRules.heat_hours.

const MAX_LEVEL: int = 5


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
		if incident.perpetrator_id != person_id or incident.reported_by == 0:
			continue
		if sim.clock.tick - incident.reported_tick >= window:
			continue
		var crime := sim.content.crime(incident.crime_id)
		total += crime.severity if crime != null else 0
	return mini(ceili(float(total) / rules.severity_per_level), MAX_LEVEL)
