class_name WorkSystem
extends SimSystem
## Shifts as obligations (T-0060): once a minute, people with a job leave for work in time.
## At leave time (the shift start minus the walk and a margin), NPCs, and the idle player
## with free will on, drop what they're doing (sleep too) and queue `work` on their
## workplace; the player gets a reminder an hour before. The margin, the retry interval and how
## far ahead the walk is worked out are in data/economy.json "work". Runs before AutonomySystem, so
## obligations go before free will. No state: everything is computed from the schedule.

## The reminder comes this long before the shift starts.
const REMINDER_MINUTES: int = 60


func on_minute(sim: Sim) -> void:
	var now := sim.clock.tick
	var minute := SimClock.STEPS_PER_GAME_MINUTE
	var economy := sim.content.economy
	for person: Person in sim.world.people.values():
		if person.job == null:
			continue
		_settle_shifts(sim, person)
		if person.job == null:
			continue  # fired just now
		var shift := Jobs.next_shift(sim, person)
		if shift.x < 0:
			continue
		if person.id == sim.world.player_id and now == shift.x - REMINDER_MINUTES * minute:
			sim.emit_event(&"work_reminder", {"person_id": person.id, "job_id": person.job.job_id, "start_tick": shift.x})
		if now < shift.x - economy.look_ahead_hours * 60 * minute or _on_the_way(sim, person):
			continue  # far from the next shift, or already there or going: nothing to work out
		var leave := shift.x - (Jobs.travel_minutes(sim, person) + economy.leave_margin) * minute
		if now < leave or ((now - leave) / minute) % economy.work_retry_minutes != 0:
			continue
		if not _goes_alone(sim, person) or _almost_done(sim, person):
			continue
		_go(sim, person)


## Settles an attended shift once its window is over and they're no longer working it, and
## counts a shift that ends this minute, that they never turned up for, as missed (T-0061,
## T-0077).
static func _settle_shifts(sim: Sim, person: Person) -> void:
	var employment := person.job
	if employment.shift_start >= 0 and not Jobs.working(sim, person):
		var window := Jobs.shift_on(sim, person, employment.shift_start / SimClock.ticks_for(1))
		if window.x != employment.shift_start or sim.clock.tick >= window.y:
			Careers.settle(sim, person)
			if person.job == null:
				return
	for day: int in [sim.clock.day() - 1, sim.clock.day()]:
		var window := Jobs.shift_on(sim, person, day)
		if window.y != sim.clock.tick or window.x < SimClock.ticks_for(employment.hired_day):
			continue
		if employment.last_shift_start != window.x and employment.shift_start != window.x:
			Careers.miss(sim, person)
			return


## True if work is already queued or being done.
static func _on_the_way(sim: Sim, person: Person) -> bool:
	for action: Action in person.action_queue:
		var def := sim.content.interaction(action.interaction_id)
		if def != null and def.work:
			return true
	return false


## True if the front action is performing and ends within leave_margin minutes (finishing a
## shower first still gets them there on time; the next retry sends them).
static func _almost_done(sim: Sim, person: Person) -> bool:
	if person.action_queue.is_empty() or person.action_queue[0].state != Action.PERFORMING:
		return false
	var action: Action = person.action_queue[0]
	var def := sim.content.interaction(action.interaction_id)
	return def != null and def.duration_minutes > 0 and def.duration_minutes - action.minutes_done <= sim.content.economy.leave_margin


## NPCs always go; the player only with free will on and no input for IDLE_MINUTES.
static func _goes_alone(sim: Sim, person: Person) -> bool:
	if person.id != sim.world.player_id:
		return true
	return person.free_will and sim.clock.tick - person.last_input_tick >= AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE


## Drops the current action (waking a sleeper) and queues work at the front. An NPC's other
## queued plans go too (they'd be stale after a shift); the player's stay queued (T-0077).
static func _go(sim: Sim, person: Person) -> void:
	var workplace := Jobs.workplace(sim, person)
	if workplace == null:
		return
	if not person.action_queue.is_empty():
		var front: Action = person.action_queue[0]
		var def := sim.content.interaction(front.interaction_id)
		if def != null and def.routine == "sleep" and front.state == Action.PERFORMING:
			sim.emit_event(&"woke_for_work", {"person_id": person.id})
		ActionSystem.cancel_front(sim, person, "work")
	if person.id != sim.world.player_id:
		person.action_queue.clear()
	person.path.clear()
	var action := Action.new("work", workplace.id)
	action.id = sim.world.new_id()
	person.action_queue.insert(0, action)
	sim.emit_event(&"left_for_work", {"person_id": person.id, "job_id": person.job.job_id})
