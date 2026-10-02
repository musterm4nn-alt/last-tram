class_name EconomySystem
extends SimSystem
## The weekly money cycle (D29): Monday morning benefit and pensions, then rent and bills
## (Housing, T-0062); on payday (Friday 18:00 by default) everyone's wages for the week's
## shifts go into the bank. Households far behind are evicted after rent, and empty flats are
## let every day (Moving, T-0066). No state.


## Jobless residents apply for vacancies on Monday at this hour (T-0064).
const APPLY_HOUR: int = 9


func on_minute(sim: Sim) -> void:
	var economy := sim.content.economy
	if sim.clock.weekday() == 0 and sim.clock.minute_of_day() == economy.benefit_hour * 60:
		Housing.pay_benefits(sim)
	if sim.clock.weekday() == 0 and sim.clock.minute_of_day() == economy.rent_hour * 60:
		Housing.collect_rent(sim)
		Moving.evict_overdue(sim)
	if sim.clock.minute_of_day() == economy.move_in_hour * 60:
		Moving.daily(sim)
	if sim.clock.weekday() == 0 and sim.clock.minute_of_day() == APPLY_HOUR * 60:
		Hiring.residents_apply(sim)
	if sim.clock.weekday() == economy.payday_weekday and sim.clock.minute_of_day() == economy.payday_hour * 60:
		var ids: Array = sim.world.people.keys()
		ids.sort()
		for id: int in ids:
			Careers.pay(sim, sim.world.people[id])
