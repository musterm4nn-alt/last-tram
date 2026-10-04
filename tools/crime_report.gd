class_name CrimeReport
extends RefCounted
## The crime line of a headless run (T-0097): crimes per day by kind, who committed them, and
## what the police did. Used by tools/sim_runner.gd and tests/sim/test_npc_crime.gd.


## "crime: 9 in 7 days (1.3 a day): shoplifting 6, pickpocketing 3 | by residents 9 |
## reported 4, arrests 3, escaped 1 | fines €400.00, stolen €31.50".
static func line(sim: Sim, days: int) -> String:
	var kinds: Dictionary[String, int] = {}
	var by_residents := 0
	var reported := 0
	var closed := 0
	var lost := 0
	var stolen := 0
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		kinds[incident.crime_id] = kinds.get(incident.crime_id, 0) + 1
		by_residents += 1 if incident.perpetrator_id != sim.world.player_id else 0
		reported += 1 if incident.reported_by != 0 else 0
		closed += 1 if incident.closed_tick >= 0 else 0
		lost += 1 if incident.lost_tick >= 0 else 0
		stolen += incident.stolen
	var parts := PackedStringArray()
	for crime: CrimeDef in sim.content.crimes.values():
		if kinds.has(crime.id):
			parts.append("%s %d" % [crime.id, kinds[crime.id]])
	var total := sim.world.incidents.size()
	return "crime: %d in %d days (%.1f a day)%s | by residents %d | reported %d, charged %d, escaped %d | fines %s, stolen %s" % [
		total, days, float(total) / maxi(days, 1), (": " + ", ".join(parts)) if not parts.is_empty() else "",
		by_residents, reported, closed, lost, Money.format(sim.world.ledger.sinks.get("fine", 0)), Money.format(stolen)]
