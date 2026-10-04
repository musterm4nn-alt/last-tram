class_name PoliceSystem
extends SimSystem
## The police on the street (T-0094, D36). Every step, each officer on a call chases their
## suspect (Police.chase: follow while in sight, arrest when close, walk back afterwards).
## Every minute, calls end for officers whose shift is over, officers whose suspect is no
## longer wanted walk back, and each sought person (wanted, not lost: T-0095) nobody is after
## gets the nearest free on-duty officer (Police.dispatch). No state: the calls are World.police_tasks.


func step(sim: Sim) -> void:
	for task: PoliceTask in _tasks(sim):
		if sim.world.police_tasks.has(task.officer_id):
			Police.chase(sim, task)


func on_minute(sim: Sim) -> void:
	for task: PoliceTask in _tasks(sim):
		var officer := sim.world.get_person(task.officer_id)
		if officer == null or not Jobs.working(sim, officer):
			Police.end_call(sim, task)
		elif not task.returning and Police.wanted_level(sim, task.target_id) == 0:
			Police.go_back(sim, officer, task)
	for id: int in Police.sought_people(sim):
		var suspect := sim.world.get_person(id)
		if suspect != null and not Police.pursued(sim, id):
			Police.dispatch(sim, suspect)


## The calls in ascending officer id (a stable order before and after loading).
static func _tasks(sim: Sim) -> Array[PoliceTask]:
	var ids: Array = sim.world.police_tasks.keys()
	ids.sort()
	var out: Array[PoliceTask] = []
	for id: int in ids:
		out.append(sim.world.police_tasks[id])
	return out
