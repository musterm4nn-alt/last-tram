class_name Moving
extends RefCounted
## Losing a home and finding one (T-0066, D29; static, no state): eviction after weeks of
## unpaid rent, renting an empty flat (homeless households, the player on the phone) and
## newcomers for flats that stay empty. Thresholds are in economy.json "housing".


## Private home lots nobody lives in, in id order.
static func empty_homes(sim: Sim) -> Array[Lot]:
	var lived_in: Dictionary[int, bool] = {}
	for household: Household in sim.world.households.values():
		lived_in[household.home_lot_id] = true
	var ids: Array = sim.world.lots.keys()
	ids.sort()
	var out: Array[Lot] = []
	for id: int in ids:
		var lot: Lot = sim.world.lots[id]
		var place := sim.content.place(lot.place_id)
		if place != null and place.kind == "home" and lot.access == Lot.PRIVATE and not lived_in.has(id):
			out.append(lot)
	return out


## What moving into `lot` costs up front: move_in_weeks of its rent.
static func move_in_cost(sim: Sim, lot: Lot) -> int:
	var place := sim.content.place(lot.place_id) if lot != null else null
	return sim.content.economy.move_in_weeks * place.rent if place != null else 0


## Monday, right after rent: households evict_after_weeks or more behind lose their home. The
## arrears are written off (nobody was paid, so the ledger doesn't change), the fridge goes
## with the flat, and the members feel it (moodlet "evicted", a memory). Emits &"evicted"
## {household_id, lot_id} per household.
static func evict_overdue(sim: Sim) -> void:
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids:
		var household: Household = sim.world.households[id]
		var lot: Lot = sim.world.lots.get(household.home_lot_id)
		if lot == null or lot.weeks_behind < sim.content.economy.evict_after_weeks:
			continue
		lot.arrears = 0
		lot.weeks_behind = 0
		lot.vacant_since_day = sim.clock.day()
		_set_home(sim, household, 0)
		household.groceries = 0
		var none: Array[int] = []
		for member_id: int in household.member_ids:
			var person := sim.world.get_person(member_id)
			if person != null:
				Social.add_moodlet(sim, person, "evicted")
				Social.remember(sim, person, "evicted", none, -70, 90.0)
		sim.emit_event(&"evicted", {"household_id": id, "lot_id": lot.id})


## The person's household rents `lot`: "" when done, else why not: not_available (not an
## empty home), owe_rent (their current home has arrears), too_small (not enough beds) or
## cant_afford (the members' banks can't cover move_in_cost). The cost is paid as "rent" from
## the members' banks in id order; the old home becomes vacant. Emits &"moved_in"
## {household_id, lot_id, newcomers: false}.
static func rent_flat(sim: Sim, person: Person, lot: Lot) -> String:
	var household: Household = sim.world.households.get(person.household_id)
	if household == null or lot == null or not empty_homes(sim).has(lot):
		return "not_available"
	var old: Lot = sim.world.lots.get(household.home_lot_id)
	if old != null and old.arrears > 0:
		return "owe_rent"
	if household.member_ids.size() > maxi(1, ResidentGenerator.bed_places(sim, sim.content.place(lot.place_id))):
		return "too_small"
	var members: Array[Person] = []
	var savings := 0
	for member_id: int in household.member_ids:
		var member := sim.world.get_person(member_id)
		if member != null:
			members.append(member)
			savings += member.wallet.bank
	var cost := move_in_cost(sim, lot)
	if savings < cost:
		return "cant_afford"
	members.sort_custom(func(a: Person, b: Person) -> bool: return a.id < b.id)
	var left := cost
	for member: Person in members:
		var amount := mini(left, member.wallet.bank)
		if amount > 0 and Money.charge(sim, member, amount, "rent", lot.place_id):
			left -= amount
	if old != null:
		old.vacant_since_day = sim.clock.day()
	_set_home(sim, household, lot.id)
	lot.vacant_since_day = -1
	sim.emit_event(&"moved_in", {"household_id": household.id, "lot_id": lot.id, "newcomers": false})
	return ""


## Every day at move_in_hour, for each empty home in id order: a flat newly found empty starts
## counting its days; otherwise the first homeless household (by id, never the player's) that
## rent_flat accepts moves in, or, once it has been empty vacant_days, newcomers do
## (&"moved_in" with newcomers: true).
static func daily(sim: Sim) -> void:
	var today := sim.clock.day()
	for lot: Lot in empty_homes(sim):
		if lot.vacant_since_day < 0:
			lot.vacant_since_day = today
			continue
		if _homeless_move_in(sim, lot):
			continue
		if today - lot.vacant_since_day >= sim.content.economy.vacant_days:
			var household := ResidentGenerator.newcomers(sim, lot)
			if household != null:
				lot.vacant_since_day = -1
				sim.emit_event(&"moved_in", {"household_id": household.id, "lot_id": lot.id, "newcomers": true})


## Households without a home, in id order.
static func homeless(sim: Sim) -> Array[Household]:
	var ids: Array = sim.world.households.keys()
	ids.sort()
	var out: Array[Household] = []
	for id: int in ids:
		var household: Household = sim.world.households[id]
		if household.home_lot_id <= 0 and not household.member_ids.is_empty():
			out.append(household)
	return out


static func _homeless_move_in(sim: Sim, lot: Lot) -> bool:
	var player := sim.world.player()
	for household: Household in homeless(sim):
		if player != null and household.id == player.household_id:
			continue
		var first := sim.world.get_person(household.member_ids[0])
		if first != null and rent_flat(sim, first, lot).is_empty():
			return true
	return false


static func _set_home(sim: Sim, household: Household, lot_id: int) -> void:
	household.home_lot_id = lot_id
	for member_id: int in household.member_ids:
		var person := sim.world.get_person(member_id)
		if person != null:
			person.home_lot_id = lot_id
