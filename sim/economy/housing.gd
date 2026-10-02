class_name Housing
extends RefCounted
## Monday's part of the weekly cycle (T-0062, D29; static, no state): benefit and pensions
## first, then rent and bills. Rent comes from the home place's content; what isn't paid
## becomes the lot's arrears.


## The person's equal share of their home's weekly rent (0 without a home).
static func rent_share(sim: Sim, person: Person) -> int:
	var household := Groceries.home_household(sim, person)
	if household == null or household.member_ids.is_empty():
		return 0
	return home_rent(sim, household) / household.member_ids.size()


## The weekly rent of the household's home, in cents.
static func home_rent(sim: Sim, household: Household) -> int:
	var lot: Lot = sim.world.lots.get(household.home_lot_id)
	var place := sim.content.place(lot.place_id) if lot != null else null
	return place.rent if place != null else 0


## Pensions for people at retirement age; benefit (a base plus help with the rent, capped)
## for registered unemployed people under it.
static func pay_benefits(sim: Sim) -> void:
	var economy := sim.content.economy
	for person: Person in _people(sim):
		if person.age_years >= economy.retirement_age:
			Money.earn(sim, person, economy.pension_week, "pension")
		elif person.job == null and person.benefit_registered:
			Money.earn(sim, person, economy.benefit_week + mini(rent_share(sim, person), economy.housing_cap), "benefit")


## Each household's members pay equal shares of the rent and the bills from the bank. What
## isn't paid becomes arrears (&"rent_unpaid" {household_id, lot_id, owed, weeks_behind});
## a week paid in full also pays off arrears where the money is there (&"rent_paid").
static func collect_rent(sim: Sim) -> void:
	var ids: Array = sim.world.households.keys()
	ids.sort()
	for id: int in ids:
		var household: Household = sim.world.households[id]
		var lot: Lot = sim.world.lots.get(household.home_lot_id)
		var members: Array[Person] = []
		for member_id: int in household.member_ids:
			if sim.world.get_person(member_id) != null:
				members.append(sim.world.get_person(member_id))
		if lot == null or members.is_empty():
			continue
		var unpaid := 0
		for i: int in members.size():
			unpaid += _pay_share(sim, members[i], _share(home_rent(sim, household), members.size(), i), "rent", lot.place_id)
			unpaid += _pay_share(sim, members[i], _share(sim.content.economy.bills_week, members.size(), i), "bill", lot.place_id)
		if unpaid > 0:
			lot.arrears += unpaid
			lot.weeks_behind += 1
			sim.emit_event(&"rent_unpaid", {"household_id": id, "lot_id": lot.id, "owed": lot.arrears, "weeks_behind": lot.weeks_behind})
			continue
		for member: Person in members:
			var amount := mini(lot.arrears, member.wallet.bank)
			if amount > 0 and Money.charge(sim, member, amount, "rent", lot.place_id):
				lot.arrears -= amount
		if lot.arrears == 0:
			lot.weeks_behind = 0
		sim.emit_event(&"rent_paid", {"household_id": id, "lot_id": lot.id, "owed": lot.arrears})


## Member `index` of `count` pays `total / count`; the last one also pays the remainder.
static func _share(total: int, count: int, index: int) -> int:
	return total / count + (total % count if index == count - 1 else 0)


## Charges what the bank allows (all or nothing); returns what stays unpaid.
static func _pay_share(sim: Sim, person: Person, amount: int, reason: String, detail: String) -> int:
	if amount <= 0 or Money.charge(sim, person, amount, reason, detail):
		return 0
	return amount


static func _people(sim: Sim) -> Array[Person]:
	var ids: Array = sim.world.people.keys()
	ids.sort()
	var out: Array[Person] = []
	for id: int in ids:
		out.append(sim.world.people[id])
	return out
