class_name WorkSession
extends RefCounted
## How a shift is worked (D10): the work action calls begin when it starts, on_minute every
## personal minute, and finish when it ends. Implementations keep no state of their own (the
## saved work action and the job schedule hold it), so any job can later become playable by
## swapping its session (WorkSessions.for_job).


## The shift starts (the person has arrived at their staff slot).
func begin(_sim: Sim, _person: Person, _action: Action) -> void:
	pass


## One minute of work.
func on_minute(_sim: Sim, _person: Person, _action: Action) -> void:
	pass


## The shift ends; `completed` is false when it ended before the shift's end.
func finish(sim: Sim, person: Person, action: Action, completed: bool) -> WorkResult:
	var result := WorkResult.new()
	result.job_id = person.job.job_id if person.job != null else ""
	result.left_early = not completed
	var window := Jobs.shift_window(sim, person, action.started_tick)
	if window.x < 0:
		return result
	var started := maxi(action.started_tick, window.x)
	var ended := mini(sim.clock.tick, window.y)
	result.minutes = maxi(0, (ended - started) / SimClock.STEPS_PER_GAME_MINUTE)
	result.late_minutes = maxi(0, (action.started_tick - window.x) / SimClock.STEPS_PER_GAME_MINUTE)
	return result


## True when the worker is out of sight for the shift (the rabbit hole).
func hidden() -> bool:
	return false
