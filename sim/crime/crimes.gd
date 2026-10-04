class_name Crimes
extends RefCounted
## Committing crimes (T-0091, docs/design/crime-and-police.md). A finished interaction with
## a `crime` records an Incident and emits `crime_committed`; witnesses and the police
## (later tickets) react to that.


## Records `crime_id` committed by `person` against `target_id` (a person or object, or 0)
## where the person stands. Returns the new incident. With a person target, `outcome` is how
## the sneaky act went (T-0096): "fail" means the victim noticed (they become a witness and
## nothing is taken); otherwise they didn't, and a crime that steals cash takes it
## (&"stolen" {person_id, victim_id, amount, incident_id, crime_id}, also when there was
## nothing). An object in someone's home is theirs (T-0098: home_victim); they see the
## burglar only if they can (awake, in sight).
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
	elif victim == null and sim.world.objects.has(target_id):
		victim = home_victim(sim, incident.lot_id)
	var crime := sim.content.crime(crime_id)
	if victim != null and outcome != "fail" and crime != null and crime.steal_share > 0.0:
		var held := victim.wallet.cash if crime.steal_account == Money.CASH else victim.wallet.bank
		var amount := mini(floori(maxi(held, 0) * crime.steal_share), crime.steal_max)
		incident.stolen = Money.steal(sim, victim, person, amount, crime_id, crime.steal_account)
		sim.emit_event(&"stolen", {"person_id": person.id, "victim_id": victim.id, "amount": incident.stolen,
			"incident_id": incident.id, "crime_id": crime_id})
	Witnesses.record(sim, incident, unaware)
	Police.maybe_report(sim, incident)
	sim.emit_event(&"crime_committed", {"incident_id": incident.id, "crime_id": crime_id, "person_id": person.id})
	return incident


## Whose home `lot_id` is, for a burglary (T-0098): of the people living there, the one with
## the most in the bank (ties: the lower id); null for no one.
static func home_victim(sim: Sim, lot_id: int) -> Person:
	var best: Person = null
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		var person := sim.world.get_person(id)
		if lot_id != 0 and person.home_lot_id == lot_id and (best == null or person.wallet.bank > best.wallet.bank):
			best = person
	return best


## The incidents `person_id` committed, oldest first.
static func committed_by(sim: Sim, person_id: int) -> Array[Incident]:
	var out: Array[Incident] = []
	for id: int in sim.world.incidents:
		var incident: Incident = sim.world.incidents[id]
		if incident.perpetrator_id == person_id:
			out.append(incident)
	out.sort_custom(func(a: Incident, b: Incident) -> bool: return a.id < b.id)
	return out
