class_name Trespass
extends RefCounted
## Trespassing (T-0098, docs/design/crime-and-police.md): walking onto a lot you may not be
## on (someone else's home, a shop while it's closed) commits "trespassing" there, once per
## visit. Walking through on the way somewhere else isn't (routes cut through the odd flat and
## shop, and upstairs neighbours cross the ground-floor flat of Haus 3), nor standing in the
## doorway; nor is staying on
## after a shop closes, coming in just after closing time, coming in to work, or an officer
## on a call. PoliceSystem checks
## everyone once a minute. Static, no state.

const CRIME_ID: String = "trespassing"
## How long after closing time a shop becomes off limits.
const CLOSING_GRACE_MINUTES: int = 30


## Checks everyone (ascending id): whoever stepped onto another lot since the last check, may
## not be there and isn't just passing through commits trespassing. Updates Person.on_lot_id
## (not while passing through, so stopping there later still counts).
static func check(sim: Sim) -> void:
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		var person := sim.world.get_person(id)
		var lot := Lots.lot_at(sim, person.cell())
		var lot_id := lot.id if lot != null else 0
		if lot_id == person.on_lot_id:
			continue
		if lot != null and forbidden(sim, person, lot):
			if passing_through(sim, person, lot) or doorway(sim, person.cell()):
				continue  # not settled in here (yet): checked again next minute
			Crimes.commit(sim, person, CRIME_ID, 0)
		person.on_lot_id = lot_id


## True if `person` has no business on `lot` now. A shop is off limits only once it has been
## closed for CLOSING_GRACE_MINUTES (customers on their way when it closed aren't burglars).
static func forbidden(sim: Sim, person: Person, lot: Lot) -> bool:
	if Lots.may_enter(sim, person, lot) or Police.on_call(sim, person):
		return false
	if lot.access == Lot.HOURS:
		var earlier := SimClock.new()
		earlier.tick = maxi(0, sim.clock.tick - SimClock.ticks_for(0, 0, CLOSING_GRACE_MINUTES))
		if Lots.is_open(lot, earlier):
			return false
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	return job == null or job.place_id != lot.place_id


## True on a doorway: a walkable cell that blocks sight (a door). Standing in one, chatting or
## waiting, isn't being inside.
static func doorway(sim: Sim, cell: Vector3i) -> bool:
	var terrain := sim.world.grid.terrain_def_at(cell)
	return terrain.walkable and terrain.blocks_sight


## True while `person` walks a route that ends off `lot` (direct control has no route, so it
## never counts as passing through).
static func passing_through(sim: Sim, person: Person, lot: Lot) -> bool:
	return not person.path.is_empty() and Lots.lot_at(sim, person.path[-1]) != lot
