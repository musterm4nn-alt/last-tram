class_name Careers
extends RefCounted
## Pay and performance (T-0061; static, no state): what a shift earns, how it moves
## performance, and promotion, warnings and firing. The numbers are in data/economy.json
## ("performance"); the record is on Employment.


## After a shift ends (WorkSession result): the wage for its minutes goes into `unpaid`, and
## performance moves by how it went.
static func record_shift(sim: Sim, person: Person, result: WorkResult) -> void:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	if job == null:
		return
	var rules := sim.content.economy.performance
	var employment := person.job
	employment.unpaid += result.minutes * _level(job, employment).wage / 60
	var shift_minutes := job.positions[employment.position].hours() * 60
	var delta := 0.0
	if result.left_early and result.minutes < shift_minutes - 30:
		delta -= rules["left_early"]
	else:
		delta += rules["shift_done"]
		if Mood.compute(person, sim.content) > 0.0:
			delta += rules["good_mood"]
		employment.level_shifts += 1
	if employment.shifts_worked > 0:  # a first day is forgiven (and day one of a new game starts at 08:00)
		delta -= floorf(result.late_minutes / 5.0) * rules["per_5_minutes_late"]
	employment.shifts_worked += 1
	_change(sim, person, delta)


## A shift came and went without them: performance drops by "missed".
static func miss(sim: Sim, person: Person) -> void:
	person.job.shifts_missed += 1
	sim.emit_event(&"shift_missed", {"person_id": person.id, "job_id": person.job.job_id})
	_change(sim, person, -sim.content.economy.performance["missed"])


## Pays out the person's unpaid wages into the bank (&"wages_paid" {person_id, amount}).
static func pay(sim: Sim, person: Person) -> void:
	if person.job == null or person.job.unpaid <= 0:
		return
	var amount := person.job.unpaid
	person.job.unpaid = 0
	Money.earn(sim, person, amount, "wage", Money.BANK, person.job.job_id)
	Social.add_moodlet(sim, person, "payday")
	sim.emit_event(&"wages_paid", {"person_id": person.id, "amount": amount})


## Ends the job: unpaid wages are paid at once, the position opens up, and they remember it
## (&"fired" {person_id, job_id, reason}).
static func fire(sim: Sim, person: Person, reason: String) -> void:
	if person.job == null:
		return
	var job_id := person.job.job_id
	pay(sim, person)
	person.job = null
	Social.add_moodlet(sim, person, "fired")
	var none: Array[int] = []
	Social.remember(sim, person, "fired", none, -60, 80.0)
	sim.emit_event(&"fired", {"person_id": person.id, "job_id": job_id, "reason": reason})


static func _change(sim: Sim, person: Person, delta: float) -> void:
	var rules := sim.content.economy.performance
	var employment := person.job
	employment.performance = clampf(employment.performance + delta, 0.0, 100.0)
	if employment.performance <= rules["fire_at"]:
		fire(sim, person, "performance")
		return
	if employment.performance < rules["warn_below"]:
		if not employment.warned:
			employment.warned = true
			sim.emit_event(&"job_warning", {"person_id": person.id, "job_id": employment.job_id})
	else:
		employment.warned = false
	var job := sim.content.job(employment.job_id)
	if employment.performance >= rules["promote_at"] and employment.level_shifts >= int(rules["promote_after_shifts"]) and employment.level < job.levels.size() - 1:
		employment.level += 1
		employment.level_shifts = 0
		employment.performance = rules["after_promotion"]
		Social.add_moodlet(sim, person, "promoted")
		var none: Array[int] = []
		Social.remember(sim, person, "promoted", none, 50, 70.0)
		sim.emit_event(&"promoted", {"person_id": person.id, "job_id": job.id, "title": job.levels[employment.level].title})


static func _level(job: JobDef, employment: Employment) -> JobLevel:
	return job.levels[clampi(employment.level, 0, job.levels.size() - 1)]


## Words for performance: "doing well" (70+), "doing okay" (40+), "struggling".
static func performance_text(employment: Employment) -> String:
	if employment.performance >= 70.0:
		return "doing well"
	return "doing okay" if employment.performance >= 40.0 else "struggling"
