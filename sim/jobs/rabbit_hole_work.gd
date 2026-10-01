class_name RabbitHoleWork
extends WorkSession
## The default WorkSession (D10): the worker goes into the building, or takes the tram, and is
## hidden until the shift ends; their needs change by the job's need_rates.


func on_minute(sim: Sim, person: Person, _action: Action) -> void:
	var job := sim.content.job(person.job.job_id) if person.job != null else null
	if job == null:
		return
	for need_id: String in job.need_rates:
		var before := float(person.needs.get(need_id, 0.0))
		person.needs[need_id] = clampf(before + job.need_rates[need_id] / 60.0, 0.0, 100.0)


func hidden() -> bool:
	return true
