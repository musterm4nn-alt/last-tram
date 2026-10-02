class_name Staffing
extends RefCounted
## Who is serving where (T-0065; static, no state): a counter sells only while someone works
## an on-site shift on its place. Derived from the work actions, so nothing is saved.


## The place ids of every on-site job, sorted.
static func places(content: ContentDB) -> PackedStringArray:
	var out := PackedStringArray()
	for job: JobDef in content.jobs.values():
		if job.session == JobDef.ON_SITE and not out.has(job.place_id):
			out.append(job.place_id)
	out.sort()
	return out


## True while someone works (Jobs.working) an on-site job at the place `place_id`.
static func serving(sim: Sim, place_id: String) -> bool:
	for person: Person in sim.world.people.values():
		if person.job == null or not Jobs.working(sim, person):
			continue
		var job := sim.content.job(person.job.job_id)
		if job != null and job.session == JobDef.ON_SITE and job.place_id == place_id:
			return true
	return false


## True when the lot's place is served by on-site staff, it is open, and nobody is serving.
static func unserved(sim: Sim, lot: Lot) -> bool:
	return lot != null and places(sim.content).has(lot.place_id) and Lots.is_open(lot, sim.clock) and not serving(sim, lot.place_id)
