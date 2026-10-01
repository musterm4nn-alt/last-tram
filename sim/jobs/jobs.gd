class_name Jobs
extends RefCounted
## Questions and changes about jobs and positions (T-0058, D29; static, no state).
## A position is one ShiftDef of a JobDef; Person.job says who fills it.


## The person in that position, or null when it is vacant.
static func holder(world: World, job_id: String, position: int) -> Person:
	for person: Person in world.people.values():
		if person.job != null and person.job.job_id == job_id and person.job.position == position:
			return person
	return null


## Every vacant position, in content order: [{"job_id": String, "position": int}].
static func vacancies(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for job: JobDef in sim.content.jobs.values():
		for position: int in job.positions.size():
			if holder(sim.world, job.id, position) == null:
				out.append({"job_id": job.id, "position": position})
	return out


## Gives `person` the position (level 0, performance 50, hired today) and emits &"hired"
## {person_id, job_id, position}. False, with no change, if it doesn't exist or is taken.
static func hire(sim: Sim, person: Person, job_id: String, position: int) -> bool:
	var job := sim.content.job(job_id)
	if person == null or job == null or position < 0 or position >= job.positions.size():
		return false
	if holder(sim.world, job_id, position) != null:
		return false
	var employment := Employment.new()
	employment.job_id = job_id
	employment.position = position
	employment.hired_day = sim.clock.day()
	person.job = employment
	sim.emit_event(&"hired", {"person_id": person.id, "job_id": job_id, "position": position})
	return true


## The start and end ticks of the person's shift that starts on `day`, or (-1, -1) on a day off
## or without a job. A shift past midnight ends on the next day.
static func shift_on(sim: Sim, person: Person, day: int) -> Vector2i:
	var none := Vector2i(-1, -1)
	if person.job == null:
		return none
	var job := sim.content.job(person.job.job_id)
	if job == null or person.job.position >= job.positions.size():
		return none
	var shift := job.positions[person.job.position]
	if not shift.days.has(day % SimClock.DAYS_PER_WEEK):
		return none
	var start := SimClock.ticks_for(day, shift.from)
	return Vector2i(start, start + SimClock.ticks_for(0, shift.hours()))


## The shift (start and end ticks) that `tick` falls in, counting the hour before it starts:
## today's, or yesterday's when it runs past midnight. (-1, -1) for none.
static func shift_window(sim: Sim, person: Person, tick: int) -> Vector2i:
	var day := tick / SimClock.ticks_for(1)
	for start_day: int in [day, day - 1, day + 1]:
		var window := shift_on(sim, person, start_day)
		if window.x >= 0 and tick >= window.x - SimClock.ticks_for(0, 1) and tick < window.y:
			return window
	return Vector2i(-1, -1)


## The work action started performing: begin the job's WorkSession and emit &"shift_started"
## {person_id, job_id, late_minutes}.
static func start_shift(sim: Sim, person: Person, action: Action) -> void:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	if job == null:
		return
	WorkSessions.for_job(job).begin(sim, person, action)
	var window := shift_window(sim, person, action.started_tick)
	var late := maxi(0, (action.started_tick - window.x) / SimClock.STEPS_PER_GAME_MINUTE) if window.x >= 0 else 0
	sim.emit_event(&"shift_started", {"person_id": person.id, "job_id": job.id, "late_minutes": late})


## One personal minute of work (the session applies the job's needs).
static func work_minute(sim: Sim, person: Person, action: Action) -> void:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	if job != null:
		WorkSessions.for_job(job).on_minute(sim, person, action)


## True once the shift the work action started in is over (or the person lost the job).
static func shift_over(sim: Sim, person: Person, action: Action) -> bool:
	var window := shift_window(sim, person, action.started_tick)
	return window.x < 0 or sim.clock.tick >= window.y


## A PERFORMING work action ends (finished when `completed`, else cancelled or failed): the
## session's WorkResult goes out as &"shift_ended" {person_id, job_id, minutes, late_minutes,
## left_early}. Returns the result (T-0061 pays from it).
static func end_shift(sim: Sim, person: Person, action: Action, completed: bool) -> WorkResult:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	var result := WorkSessions.for_job(job).finish(sim, person, action, completed) if job != null else WorkResult.new()
	sim.emit_event(&"shift_ended", {"person_id": person.id, "job_id": result.job_id, "minutes": result.minutes,
		"late_minutes": result.late_minutes, "left_early": result.left_early})
	return result


## True while the person performs their work action.
static func working(sim: Sim, person: Person) -> bool:
	if person.action_queue.is_empty() or person.action_queue[0].state != Action.PERFORMING:
		return false
	var def := sim.content.interaction(person.action_queue[0].interaction_id)
	return def != null and def.work


## True while the person works out of sight (the rabbit hole).
static func hidden(sim: Sim, person: Person) -> bool:
	if not working(sim, person) or person.job == null:
		return false
	var job := sim.content.job(person.job.job_id)
	return job != null and WorkSessions.for_job(job).hidden()


## True if the position's working hours never fall in the routine's sleep window.
static func fits_routine(content: ContentDB, job: JobDef, position: int, routine_id: String) -> bool:
	var routine := content.routine(routine_id)
	if routine == null:
		return false
	var shift := job.positions[position]
	for i: int in shift.hours():
		if Routines.in_hours(routine.sleep_hours, (shift.from + i) % 24):
			return false
	return true


## "daily", "Mon–Fri", "Fri–Sun", "Mon, Wed".
static func days_text(shift: ShiftDef) -> String:
	var days := Array(shift.days)
	days.sort()
	if days.size() == SimClock.DAYS_PER_WEEK:
		return "daily"
	var names: PackedStringArray = []
	for day: int in days:
		names.append(SimClock.WEEKDAY_NAMES[day])
	if days.size() >= 3 and int(days.back()) - int(days[0]) == days.size() - 1:
		return "%s–%s" % [names[0], names[names.size() - 1]]
	return ", ".join(names)


## "Office clerk (Mon–Fri 9–17)" for the person's job and level, "" without one.
static func describe(content: ContentDB, person: Person) -> String:
	var job := content.job(person.job.job_id) if person.job != null else null
	if job == null:
		return ""
	var shift := job.positions[person.job.position]
	var title := job.levels[clampi(person.job.level, 0, job.levels.size() - 1)].title
	return "%s (%s %d–%d)" % [title, days_text(shift), shift.from, shift.to]


## New games: the player gets the content's player_job (its first free position), then every
## position, in content order, is filled with a chance of start_filled by a jobless resident
## under retirement age, preferring one whose routine fits (else they get the first routine,
## by id, that fits). Draws come from the "jobs" stream.
static func fill_at_start(sim: Sim) -> void:
	var rng := sim.rng.stream("jobs")
	var player := sim.world.player()
	var player_job := sim.content.job(sim.content.economy.player_job)
	if player != null and player_job != null:
		for position: int in player_job.positions.size():
			if hire(sim, player, player_job.id, position):
				break
	var ids: Array = sim.world.people.keys()
	ids.sort()
	var routine_ids: Array = sim.content.routines.keys()
	routine_ids.sort()
	for job: JobDef in sim.content.jobs.values():
		for position: int in job.positions.size():
			if holder(sim.world, job.id, position) != null or rng.randf() >= job.start_filled:
				continue
			var candidates: Array[Person] = []
			var fitting: Array[Person] = []
			for id: int in ids:
				var person: Person = sim.world.people[id]
				if id == sim.world.player_id or person.job != null or person.age_years >= sim.content.economy.retirement_age:
					continue
				candidates.append(person)
				if fits_routine(sim.content, job, position, Routines.routine_of(sim, person).id):
					fitting.append(person)
			var pool := fitting if not fitting.is_empty() else candidates
			if pool.is_empty():
				continue
			var chosen: Person = pool[rng.randi_range(0, pool.size() - 1)]
			if fitting.is_empty():
				for routine_id: String in routine_ids:
					if fits_routine(sim.content, job, position, routine_id):
						chosen.routine_id = routine_id
						break
			hire(sim, chosen, job.id, position)
