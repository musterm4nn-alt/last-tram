class_name Crimes
extends RefCounted
## Committing crimes (T-0091, docs/design/crime-and-police.md). A finished interaction with
## a `crime` records an Incident and emits `crime_committed`; witnesses and the police
## (later tickets) react to that.


## Records `crime_id` committed by `person` against `target_id` (a person or object, or 0)
## where the person stands. Returns the new incident. With a person target, `outcome` is how
## the sneaky act went (T-0096): "fail" means the victim noticed (they become a witness and
## nothing is taken); otherwise they didn't, and a crime that steals cash takes it
## (&"stolen" {person_id, victim_id, amount, incident_id}, also when their pockets were empty).
static func commit(sim: Sim, person: Person, crime_id: String, target_id: int, outcome: String = "") -> Incident:
	var incident := Incident.new()
	incident.id = sim.world.new_id()
	incident.crime_id = crime_id
	incident.perpetrator_id = person.id
	incident.target_id = target_id
	incident.cell = person.cell()
	var lot := Lots.lot_at(sim, incident.cell)
	incident.lot_id = lot.id if lot != null else 0
	incident.tick = sim.clock.tick
	sim.world.incidents[incident.id] = incident
	var victim := sim.world.get_person(target_id)
	var unaware: Array[int] = []
	if victim != null and outcome != "fail":
		unaware.append(victim.id)
		var crime := sim.content.crime(crime_id)
		if crime != null and crime.steal_share > 0.0:
			var amount := mini(floori(victim.wallet.cash * crime.steal_share), crime.steal_max)
			incident.stolen = Money.steal(sim, victim, person, amount, crime_id)
			sim.emit_event(&"stolen", {"person_id": person.id, "victim_id": victim.id, "amount": incident.stolen, "incident_id": incident.id})
	Witnesses.record(sim, incident, unaware)
	Police.maybe_report(sim, incident)
	sim.emit_event(&"crime_committed", {"incident_id": incident.id, "crime_id": crime_id, "person_id": person.id})
	return incident


## The incidents `person_id` committed, oldest first.
static func committed_by(sim: Sim, person_id: int) -> Array[Incident]:
	var out: Array[Incident] = []
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == person_id:
			out.append(incident)
	out.sort_custom(func(a: Incident, b: Incident) -> bool: return a.id < b.id)
	return out
