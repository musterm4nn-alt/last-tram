class_name Groceries
extends RefCounted
## Household food stock in portions (T-0057, D29: the only items in M3). Static queries and
## changes; the stock itself is Household.groceries (saved).


## True when the object's food comes from a household's stock: it stands on a lot. (Objects on
## no lot, only in test rooms, are not limited.)
static func counts(sim: Sim, obj: WorldObject) -> bool:
	return obj != null and Lots.lot_at(sim, obj.origin) != null


## The household whose home is the lot under the object's origin, or null.
static func household_at(sim: Sim, obj: WorldObject) -> Household:
	if obj == null:
		return null
	var lot := Lots.lot_at(sim, obj.origin)
	if lot == null:
		return null
	for household: Household in sim.world.households.values():
		if household.home_lot_id == lot.id:
			return household
	return null


## The person's household, if it has a home; else null.
static func home_household(sim: Sim, person: Person) -> Household:
	var household: Household = sim.world.households.get(person.household_id)
	return household if household != null and household.home_lot_id > 0 else null


## "6 portions" / "1 portion" for the household of the object's home; "" outside homes.
static func stock_text(sim: Sim, obj: WorldObject) -> String:
	var household := household_at(sim, obj)
	if household == null:
		return ""
	return "%d portion%s" % [household.groceries, "" if household.groceries == 1 else "s"]


## Changes a household's stock by `delta` (kept within 0..fridge_capacity) and emits
## &"groceries_changed" {household_id, groceries}.
static func change(sim: Sim, household: Household, delta: int) -> void:
	household.groceries = clampi(household.groceries + delta, 0, sim.content.economy.fridge_capacity)
	sim.emit_event(&"groceries_changed", {"household_id": household.id, "groceries": household.groceries})


## New games: every household, in id order, gets a random starting stock from the
## "groceries" stream.
static func give_start(sim: Sim) -> void:
	var rng := sim.rng.stream("groceries")
	var range_ := sim.content.economy.start_groceries
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids:
		sim.world.households[id].groceries = rng.randi_range(range_.x, range_.y)
