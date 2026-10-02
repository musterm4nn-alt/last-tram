class_name EconomySystem
extends SimSystem
## The weekly money cycle (D29): on payday (Friday 18:00 by default) everyone's wages for the
## week's shifts go into the bank. T-0062 adds benefit, pensions, rent and bills. No state.


func on_minute(sim: Sim) -> void:
	var economy := sim.content.economy
	if sim.clock.weekday() == economy.payday_weekday and sim.clock.minute_of_day() == economy.payday_hour * 60:
		var ids: Array = sim.world.people.keys()
		ids.sort()
		for id: int in ids:
			Careers.pay(sim, sim.world.people[id])
