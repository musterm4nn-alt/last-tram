class_name Requirements
extends RefCounted
## Whether a person may start an interaction now (D29): "" when they may, otherwise the
## reason. The interaction menu, QueueInteractionCommand, free will and ActionSystem all ask
## here, so a rule added once applies everywhere. Later tickets add rules (no_food,
## not_staffed, not_your_shift, unknown_secret...). Static, no state.

## Words for each reason, for menus and notices.
const TEXT: Dictionary = {
	"closed": "closed",
	"private": "not your home",
	"cant_afford": "not enough money",
}


## Checked in order: the target object's lot is closed (opening hours) or someone else's home;
## then the price, and the bank balance a withdrawal needs. Objects on no lot (test rooms) pass the lot rules.
static func check(sim: Sim, person: Person, def: InteractionDef, target_id: int) -> String:
	if def.target == "object":
		var obj := sim.world.get_object(target_id)
		var lot := Lots.lot_at(sim, obj.origin) if obj != null else null
		if lot != null and lot.access == Lot.HOURS and not Lots.is_open(lot, sim.clock):
			return "closed"
		if lot != null and lot.access == Lot.PRIVATE and person.home_lot_id != lot.id:
			return "private"
	if def.price > 0 and not Money.can_afford(person, def.price):
		return "cant_afford"
	if def.cash_out > 0 and person.wallet.bank < def.cash_out:
		return "cant_afford"
	return ""


## TEXT for the reason, else the id with "_" read as spaces.
static func text(reason: String) -> String:
	return String(TEXT.get(reason, reason.replace("_", " ")))
