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


func to_dict() -> Dictionary:
	return {"job_id": job_id, "position": position, "level": level, "performance": performance, "hired_day": hired_day}


static func from_dict(d: Dictionary) -> Employment:
	var e := Employment.new()
	e.job_id = String(d.get("job_id", ""))
	e.position = int(d.get("position", 0))
	e.level = int(d.get("level", 0))
	e.performance = float(d.get("performance", 50.0))
	e.hired_day = int(d.get("hired_day", 0))
	return e
