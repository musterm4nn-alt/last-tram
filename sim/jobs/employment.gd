class_name Employment
extends RefCounted
## A person's job (saved as Person.job; null = no job): which position of which JobDef, the
## level on its career track, and how well they work (T-0058).

var job_id: String = ""
## Index into JobDef.positions (counts already expanded).
var position: int = 0
## Index into JobDef.levels.
var level: int = 0
## 0..100; 50 to start. Shifts move it (T-0061).
var performance: float = 50.0
## The day (SimClock.day()) they were hired.
var hired_day: int = 0
## Wages earned since the last payday, in cents (T-0061).
var unpaid: int = 0
## Shifts completed at the current level (promotion needs enough of them).
var level_shifts: int = 0
var shifts_worked: int = 0
var shifts_missed: int = 0
## A warning was given and performance hasn't recovered since.
var warned: bool = false
## Start tick of the last shift they turned up for (-1 = none), so a missed one is noticed.
var last_shift_start: int = -1


func to_dict() -> Dictionary:
	return {"job_id": job_id, "position": position, "level": level, "performance": performance, "hired_day": hired_day,
		"unpaid": unpaid, "level_shifts": level_shifts, "shifts_worked": shifts_worked, "shifts_missed": shifts_missed,
		"warned": warned, "last_shift_start": last_shift_start}


static func from_dict(d: Dictionary) -> Employment:
	var e := Employment.new()
	e.job_id = String(d.get("job_id", ""))
	e.position = int(d.get("position", 0))
	e.level = int(d.get("level", 0))
	e.performance = float(d.get("performance", 50.0))
	e.hired_day = int(d.get("hired_day", 0))
	e.unpaid = int(d.get("unpaid", 0))
	e.level_shifts = int(d.get("level_shifts", 0))
	e.shifts_worked = int(d.get("shifts_worked", 0))
	e.shifts_missed = int(d.get("shifts_missed", 0))
	e.warned = bool(d.get("warned", false))
	e.last_shift_start = int(d.get("last_shift_start", -1))
	return e
