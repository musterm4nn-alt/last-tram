class_name Temptation
extends RefCounted
## Residents committing crimes on their own (T-0097, docs/design/crime-and-police.md "NPC
## crime"): free will offers crime interactions only to the willing (dishonest or broke, not
## wanted, no crime in the last cooldown_hours), and scores them by the usual needs plus
## steal_bonus for taking cash, minus the risk of being seen. Static, no state.


## True if `person` would consider a crime now. Never the player.
static func willing(sim: Sim, person: Person) -> bool:
	var rules := sim.content.temptation_rules
	if person.id == sim.world.player_id:
		return false
	if person.personality.get_axis("honesty") > rules.honesty_below and person.wallet.total() >= rules.broke_below:
		return false
	if Police.wanted_level(sim, person.id) > 0:
		return false
	var since := sim.clock.tick - SimClock.ticks_for(0, rules.cooldown_hours)
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == person.id and incident.tick > since:
			return false
	return true


## What a crime option adds to its score for `person` (negative when risky): steal_bonus for
## a crime that takes cash, minus risk(sim, person, cell, victim_id).
static func bonus(sim: Sim, person: Person, def: InteractionDef, cell: Vector3i, victim_id: int = 0) -> float:
	var crime := sim.content.crime(def.crime)
	var gain := sim.content.temptation_rules.steal_bonus if crime != null and crime.steal_share > 0.0 else 0.0
	return gain - risk(sim, person, cell, victim_id)


## How much the people who could see `cell` put `person` off: risk_per_witness each (and
## risk_per_officer more for an officer), times 1 - bravery / 200. The victim doesn't count.
static func risk(sim: Sim, person: Person, cell: Vector3i, victim_id: int = 0) -> float:
	var rules := sim.content.temptation_rules
	var total := 0.0
	for id: int in Witnesses.find(sim, cell, person.id):
		if id == victim_id:
			continue
		total += rules.risk_per_witness
		if Police.on_duty(sim, sim.world.get_person(id)):
			total += rules.risk_per_officer
	return total * (1.0 - person.personality.get_axis("bravery") / 200.0)
