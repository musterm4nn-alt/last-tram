class_name NeedsSystem
extends SimSystem
## Decays every person's needs once per game minute. Runs after MovementSystem.
## Emits &"need_critical" once when a need crosses below its critical threshold.


func on_minute(sim: Sim) -> void:
	for person: Person in sim.world.people.values():
		for need_def: NeedDef in sim.content.needs:
			var before: float = float(person.needs.get(need_def.id, need_def.start))
			var after: float = clampf(before - need_def.decay_per_hour / 60.0, 0.0, 100.0)
			person.needs[need_def.id] = after
			if before >= need_def.critical_below and after < need_def.critical_below:
				sim.emit_event(&"need_critical", {"person_id": person.id, "need": need_def.id})
