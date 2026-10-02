class_name EconomySystem
extends SimSystem
## The weekly money cycle (D29): Monday morning benefit and pensions, then rent and bills
## (Housing, T-0062); on payday (Friday 18:00 by default) everyone's wages for the week's
## shifts go into the bank. No state.


func on_minute(sim: Sim) -> void:
	var economy := sim.content.economy
	if sim.clock.weekday() == 0 and sim.clock.minute_of_day() == economy.benefit_hour * 60:
		Housing.pay_benefits(sim)
	if sim.clock.weekday() == 0 and sim.clock.minute_of_day() == economy.rent_hour * 60:
		Housing.collect_rent(sim)
	if sim.clock.weekday() == economy.payday_weekday and sim.clock.minute_of_day() == economy.payday_hour * 60:
		var ids: Array = sim.world.people.keys()
		ids.sort()
		for id: int in ids:
			Careers.pay(sim, sim.world.people[id])
