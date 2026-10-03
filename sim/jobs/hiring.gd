class_name Hiring
extends RefCounted
## Applying for jobs, interviews, quitting and registering as unemployed (T-0064; static, no
## state). One application a day per person (Person.applied_day).

## The interview's base chance, before hygiene, mood and dress.
const BASE_CHANCE: float = 0.45


## The chance (0.05..0.95) that `person` gets the job at an interview: how they come across
## (Presentation: washed, clean clothes, dressed like the job; T-0074), their mood and the
## job's skill (T-0071).
static func chance(sim: Sim, person: Person, job: JobDef) -> float:
	var x := BASE_CHANCE
	x += Presentation.of(sim, person, job.formality)
	x += Mood.compute(person, sim.content) / 200.0
	x += Skills.level(sim.content, person, job.skill) * sim.content.skill_rules.interview_per_level
	return clampf(x, 0.05, 0.95)


## The average formality of the clothes the person wears (0 with none).
static func outfit_formality(content: ContentDB, person: Person) -> float:
	var total := 0.0
	var count := 0
	for slot: String in person.outfit.items:
		var def := content.clothing_def(person.outfit.items[slot].clothing_id)
		if def != null:
			total += def.formality
			count += 1
	return total / count if count > 0 else 0.0


## An application: refused ("" result) when the position is taken, they already applied
## today, or they're retired; otherwise an interview rolled on the "jobs" stream. Hired
## people start the next day (a current job is left first). Emits &"job_application"
## {person_id, job_id, position, hired, reason}. Returns true when hired.
static func apply(sim: Sim, person: Person, job_id: String, position: int) -> bool:
	var job := sim.content.job(job_id)
	var reason := ""
	if job == null or position < 0 or position >= job.positions.size() or Jobs.holder(sim.world, job_id, position) != null:
		reason = "taken"
	elif person.applied_day == sim.clock.day():
		reason = "already_applied"
	elif person.age_years >= sim.content.economy.retirement_age:
		reason = "retired"
	var hired := false
	if reason.is_empty():
		person.applied_day = sim.clock.day()
		hired = sim.rng.stream("jobs").randf() < chance(sim, person, job)
		if hired:
			quit(sim, person)
			Jobs.hire(sim, person, job_id, position)
			person.job.hired_day = sim.clock.day() + 1
		else:
			reason = "rejected"
	sim.emit_event(&"job_application", {"person_id": person.id, "job_id": job_id, "position": position, "hired": hired, "reason": reason})
	return hired


## Leaves the job (an open shift's minutes and unpaid wages paid at once); &"quit_job"
## {person_id, job_id}.
static func quit(sim: Sim, person: Person) -> void:
	if person.job == null:
		return
	var job_id := person.job.job_id
	Careers.close_shift(sim, person)
	Careers.pay(sim, person)
	person.job = null
	sim.emit_event(&"quit_job", {"person_id": person.id, "job_id": job_id})


## Registers for unemployment benefit (paid on Mondays while jobless); &"registered".
static func register(sim: Sim, person: Person) -> void:
	if person.benefit_registered:
		return
	person.benefit_registered = true
	sim.emit_event(&"registered", {"person_id": person.id})


## Monday (EconomySystem): every registered, jobless resident under retirement age applies to
## one random vacancy whose shift fits their routine (stream "jobs").
static func residents_apply(sim: Sim) -> void:
	var ids: Array = sim.world.people.keys()
	ids.sort()
	var rng := sim.rng.stream("jobs")
	for id: int in ids:
		var person: Person = sim.world.people[id]
		if id == sim.world.player_id or person.job != null or not person.benefit_registered or person.age_years >= sim.content.economy.retirement_age:
			continue
		var fitting: Array[Dictionary] = []
		for vacancy: Dictionary in Jobs.vacancies(sim):
			if Jobs.fits_routine(sim.content, sim.content.job(vacancy["job_id"]), vacancy["position"], Routines.routine_of(sim, person).id):
				fitting.append(vacancy)
		if not fitting.is_empty():
			var pick: Dictionary = fitting[rng.randi_range(0, fitting.size() - 1)]
			apply(sim, person, pick["job_id"], pick["position"])
