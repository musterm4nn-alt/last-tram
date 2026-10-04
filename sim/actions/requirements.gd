class_name Requirements
extends RefCounted
## Whether a person may start an interaction now (D29): "" when they may, otherwise the
## reason. The interaction menu, QueueInteractionCommand, free will and ActionSystem all ask
## here, so a rule added once applies everywhere. Later tickets add rules (unknown_secret...). Static, no state.

## Words for each reason, for menus and notices.
const TEXT: Dictionary = {
	"closed": "closed",
	"private": "not your home",
	"cant_afford": "not enough money",
	"no_food": "the fridge is empty",
	"no_home": "no home",
	"fridge_full": "the fridge is full",
	"not_your_shift": "not your shift",
	"not_staffed": "nobody's serving",
	"has_home": "you have a home",
	"unknown_secret": "you don't know about it",
}
## Reasons the menu doesn't show at all (the option isn't for this person).
const HIDDEN: PackedStringArray = ["not_your_job", "has_home", "unknown_secret", "not_a_break_in"]


## Checked in order: a homeless-only interaction for someone with a home (T-0066), or a
## secret one they haven't uncovered (T-0067); the target object's lot is closed (opening hours) or someone else's home,
## or nobody serves a staffed interaction there (T-0065); then the price, the bank balance a withdrawal needs, and groceries (food in the fridge to
## cook with, a home with room in the fridge for a bag). Objects on no lot (test rooms) pass
## the lot and food rules.
static func check(sim: Sim, person: Person, def: InteractionDef, target_id: int) -> String:
	if def.work:
		return _work(sim, person, sim.world.get_object(target_id))
	if def.homeless_only and person.home_lot_id > 0:
		return "has_home"
	if not def.requires_discovery.is_empty() and not person.discoveries.has(def.requires_discovery):
		return "unknown_secret"
	if def.target == "place":
		var place_lot: Lot = sim.world.lots.get(target_id)
		if place_lot == null:
			return "no_place"
		if not Lots.may_enter(sim, person, place_lot):
			return "private" if place_lot.access == Lot.PRIVATE else "closed"
	if def.target == "object":
		var obj := sim.world.get_object(target_id)
		var lot := Lots.lot_at(sim, obj.origin) if obj != null else null
		if lot != null and lot.access == Lot.HOURS and not Lots.is_open(lot, sim.clock):
			return "closed"
		if def.trespass:  # a break-in: only in someone else's home (T-0098)
			if lot == null or lot.access != Lot.PRIVATE or person.home_lot_id == lot.id:
				return "not_a_break_in"
		elif lot != null and lot.access == Lot.PRIVATE and person.home_lot_id != lot.id:
			return "private"
		if def.staffed and lot != null and not Staffing.serving(sim, lot.place_id):
			return "not_staffed"
	if def.price > 0 and not Money.can_afford(person, def.price):
		return "cant_afford"
	if def.cash_out > 0 and person.wallet.bank < def.cash_out:
		return "cant_afford"
	if def.uses_groceries > 0 and Groceries.counts(sim, sim.world.get_object(target_id)):
		var stock := Groceries.household_at(sim, sim.world.get_object(target_id))
		if stock == null or stock.groceries < def.uses_groceries:
			return "no_food"
	if def.adds_groceries > 0:
		var home := Groceries.home_household(sim, person)
		if home == null:
			return "no_home"
		if home.groceries + def.adds_groceries > sim.content.economy.fridge_capacity:
			return "fridge_full"
	return ""


## Work (T-0059): the object must be the person's workplace (tag and place), and it must be
## between an hour before their shift and its end.
static func _work(sim: Sim, person: Person, obj: WorldObject) -> String:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	var object_def := sim.content.object_def(obj.def_id) if obj != null else null
	var place := sim.content.place_at(obj.origin) if obj != null else null
	if job == null or object_def == null or not object_def.tags.has(job.workplace_tag) or place == null or place.id != job.place_id:
		return "not_your_job"
	if Jobs.shift_window(sim, person, sim.clock.tick).x < 0:
		return "not_your_shift"
	return ""


## TEXT for the reason, else the id with "_" read as spaces.
static func text(reason: String) -> String:
	return String(TEXT.get(reason, reason.replace("_", " ")))
