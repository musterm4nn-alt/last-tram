class_name ShopStaff
extends RefCounted
## Test helper (T-0065): counters sell only while someone serves. Tests that jump the clock
## call serve_now so the shop staff whose shift it is are behind their counters, as if they
## had come in to work.


## Every on-site worker whose shift it is (Requirements allow "work" now) stands on a free
## staff slot of their workplace and starts working; one step is run. Returns them.
static func serve_now(sim: Sim) -> Array[Person]:
	var out: Array[Person] = []
	var work := sim.content.interaction("work")
	for job: JobDef in sim.content.jobs.values():
		for position: int in job.positions.size() if job.session == JobDef.ON_SITE else 0:
			var worker := Jobs.holder(sim.world, job.id, position)
			if worker == null or Jobs.working(sim, worker):
				continue
			var counter := Jobs.workplace(sim, worker)
			if counter == null or not Requirements.check(sim, worker, work, counter.id).is_empty():
				continue
			for slot: int in counter.slot_count(sim.content):
				if Interactions.slot_fits(sim, counter.id, slot, work) and not Interactions.slot_taken(sim, counter.id, slot, worker.id):
					var cell := counter.slot_cell(sim.content, slot)
					worker.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
					worker.level = cell.z
					break
			worker.action_queue.clear()
			worker.path.clear()
			sim.submit(QueueInteractionCommand.new(worker.id, "work", counter.id))
			out.append(worker)
	sim.step()
	return out
