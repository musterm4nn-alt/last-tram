class_name JobsApp
extends RefCounted
## The phone's Jobs app (T-0064): your job and how it's going, and the open positions you can
## apply for. Pure helpers; Phone draws them with Apply, Quit and Register buttons.


## Lines about the player's own job (or that they have none and whether benefit is coming).
static func job_lines(sim: Sim, player_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	var person := sim.world.get_person(player_id)
	if person == null:
		return out
	if person.job == null:
		out.append("No job.")
		out.append("Benefit on Mondays." if person.benefit_registered else "Not registered for benefit.")
		return out
	out.append("Your job: %s" % Jobs.describe(sim.content, person))
	out.append("Performance: %s (%d)" % [Careers.performance_text(person.job), roundi(person.job.performance)])
	if person.job.hired_day > sim.clock.day():
		out.append("You start tomorrow.")
	if person.job.unpaid > 0:
		out.append("Wages due Friday: %s" % Money.format(person.job.unpaid))
	return out


## "Imbiss cook · Imbiss Anadolu · Mon–Thu 17–23 · €12.00/h" for a vacancy.
static func vacancy_text(sim: Sim, vacancy: Dictionary) -> String:
	var job := sim.content.job(String(vacancy["job_id"]))
	var shift := job.positions[int(vacancy["position"])]
	var place := sim.content.place(job.place_id)
	var where := "in the city, by tram" if job.place_id == "tram_stop_altmarkt" else place.name
	return "%s · %s · %s %d–%d · %s/h" % [job.levels[0].title, where, Jobs.days_text(shift), shift.from, shift.to, Money.format(job.levels[0].wage)]
