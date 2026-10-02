class_name Careers
extends RefCounted
## Pay and performance (T-0061; static, no state): what a shift earns, how it moves
## performance, and promotion, warnings and firing. A shift is settled once, after its window
## (T-0077), however many times the person left and came back. The numbers are in
## data/economy.json ("performance"); the record is on Employment.

## Minutes a shift may be short (besides lateness) before it counts as leaving early.
const LEFT_EARLY_SLACK: int = 30


## The person arrived for the shift starting at `window_start` (Jobs.start_shift), `late_minutes`
## after it began. Returning to the same shift keeps the first arrival's lateness; a shift
## still open from before is settled first.
static func attend(sim: Sim, person: Person, window_start: int, late_minutes: int) -> void:
	if person.job == null or person.job.shift_start == window_start:
		return
	if person.job.shift_start >= 0:
		settle(sim, person)
		if person.job == null:
			return
	person.job.shift_start = window_start
	person.job.shift_minutes = 0
	person.job.shift_late = late_minutes


## Settles the attended shift once (T-0077), after its window: the wage for every minute
## worked in it goes into `unpaid` (rounded once), performance moves by how it went, and
## colleagues who were there get to know them. Emits &"shift_settled" {person_id, job_id,
## minutes, late_minutes, left_early, pay}. No minutes inside the window: a missed shift.
static func settle(sim: Sim, person: Person) -> void:
	var employment := person.job
	if employment == null or employment.shift_start < 0:
		return
	var start := employment.shift_start
	var minutes := employment.shift_minutes
	employment.shift_start = -1
	employment.shift_minutes = 0
	var job := sim.content.job(employment.job_id)
	if job == null:
		return
	if minutes <= 0:
		miss(sim, person)
		return
	var rules := sim.content.economy.performance
	var pay := minutes * _level(job, employment).wage / 60
	employment.unpaid += pay
	employment.last_shift_start = start
	var left_early := minutes + employment.shift_late < job.positions[employment.position].hours() * 60 - LEFT_EARLY_SLACK
	var delta := 0.0
	if left_early:
		delta -= rules["left_early"]
	else:
		delta += rules["shift_done"]
		if Mood.compute(person, sim.content) > 0.0:
			delta += rules["good_mood"]
		employment.level_shifts += 1
	if employment.shifts_worked > 0:  # a first day is forgiven (and day one of a new game starts at 08:00)
		delta -= floorf(employment.shift_late / 5.0) * rules["per_5_minutes_late"]
	employment.shifts_worked += 1
	sim.emit_event(&"shift_settled", {"person_id": person.id, "job_id": job.id, "minutes": minutes,
		"late_minutes": employment.shift_late, "left_early": left_early, "pay": pay})
	Jobs.know_colleagues(sim, person, start)
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


## Ends the job: an open shift is settled and unpaid wages are paid at once, the position opens up, and they remember it
## (&"fired" {person_id, job_id, reason}).
static func fire(sim: Sim, person: Person, reason: String) -> void:
	if person.job == null:
		return
	var job_id := person.job.job_id
	close_shift(sim, person)
	pay(sim, person)
	person.job = null
	Social.add_moodlet(sim, person, "fired")
	var none: Array[int] = []
	Social.remember(sim, person, "fired", none, -60, 80.0)
	sim.emit_event(&"fired", {"person_id": person.id, "job_id": job_id, "reason": reason})


## Leaving the job mid-shift: the minutes worked so far are paid, with no judgement.
static func close_shift(sim: Sim, person: Person) -> void:
	var employment := person.job
	var job := sim.content.job(employment.job_id) if employment != null else null
	if job == null or employment.shift_start < 0:
		return
	employment.unpaid += employment.shift_minutes * _level(job, employment).wage / 60
	employment.shift_start = -1
	employment.shift_minutes = 0


## Moves performance by `delta`, then fires, warns (once, until performance rises above
## "warning_clears_at") or promotes.
static func _change(sim: Sim, person: Person, delta: float) -> void:
	var rules := sim.content.economy.performance
	var employment := person.job
	var job := sim.content.job(employment.job_id) if employment != null else null
	if job == null:
		return
	employment.performance = clampf(employment.performance + delta, 0.0, 100.0)
	if employment.performance <= rules["fire_at"]:
		fire(sim, person, "performance")
		return
	if employment.performance < rules["warn_below"]:
		if not employment.warned:
			employment.warned = true
			sim.emit_event(&"job_warning", {"person_id": person.id, "job_id": employment.job_id})
	elif employment.performance > rules["warning_clears_at"]:
		employment.warned = false
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
