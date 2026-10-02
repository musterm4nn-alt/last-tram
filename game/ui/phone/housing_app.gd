class_name HousingApp
extends RefCounted
## The phone's Housing app (T-0066): your home and its rent (or that you have none), and the
## empty flats you could rent. Pure helpers; Phone draws them with "Rent this flat" buttons.

const REFUSALS: Dictionary = {
	"not_available": "that flat has just been let",
	"owe_rent": "pay what you owe on your flat first",
	"too_small": "not enough beds for your household",
	"cant_afford": "not enough money in the bank",
}


## Lines about the player's home: where, the weekly rent, what's owed; or "No home".
static func home_lines(sim: Sim, player_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	var person := sim.world.get_person(player_id)
	if person == null:
		return out
	var lot: Lot = sim.world.lots.get(person.home_lot_id)
	if lot == null:
		out.append("No home. You sleep rough on a bench.")
		return out
	out.append("Your home: %s" % sim.content.place(lot.place_id).name)
	out.append("Rent %s a week" % Money.format(sim.content.place(lot.place_id).rent))
	if lot.arrears > 0:
		out.append("Owed: %s (%d weeks behind; evicted at %d)" % [Money.format(lot.arrears), lot.weeks_behind, sim.content.economy.evict_after_weeks])
	return out


## "Haus 5, 2nd floor left · €125.00/week · 2 beds · move in €250.00" for an empty flat.
static func flat_text(sim: Sim, lot: Lot) -> String:
	var place := sim.content.place(lot.place_id)
	var beds := ResidentGenerator.bed_places(sim, place)
	return "%s · %s/week · %d bed%s · move in %s" % [place.name, Money.format(place.rent), beds, "" if beds == 1 else "s", Money.format(Moving.move_in_cost(sim, lot))]


## The notice for a housing event about the player's household ("" otherwise).
static func notice(event: Dictionary, sim: Sim) -> String:
	var player := sim.world.player() if sim != null else null
	if player == null:
		return ""
	var data: Dictionary = event.get("data", {})
	var lot: Lot = sim.world.lots.get(int(data.get("lot_id", 0)))
	var place := sim.content.place(lot.place_id).name if lot != null else "the flat"
	match event.get("type"):
		&"evicted":
			if int(data.get("household_id", -1)) == player.household_id:
				return "Evicted: you lost your home at %s. Find a flat on the phone." % place
		&"moved_in":
			if int(data.get("household_id", -1)) == player.household_id:
				return "You moved into %s." % place
		&"rent_flat_refused":
			if int(data.get("person_id", -1)) == player.id:
				return "%s: %s" % [place, REFUSALS.get(String(data.get("reason", "")), "not possible")]
	return ""
