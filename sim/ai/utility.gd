class_name Utility
extends RefCounted
## How much a person wants what an interaction advertises (docs/design/actions-and-autonomy.md
## → Autonomy). Pure functions, no state.


## ((100 - value) / 100)² × weight: 0 when the need is full, `weight` when it is empty.
## `value` is clamped to 0..100 first.
static func urgency(value: float, weight: float) -> float:
	var missing := (100.0 - clampf(value, 0.0, 100.0)) / 100.0
	return missing * missing * weight


## Σ over the interaction's advertised needs of urgency(need value, need weight) ×
## min(advertised amount, 100 - need value). Capping by the room left stops a nearly rested
## person from wanting 80 energy of sleep. Needs the person lacks count as 100 (full);
## unknown need ids are skipped.
static func need_score(person: Person, def: InteractionDef, content: ContentDB) -> float:
	var total := 0.0
	for need_id: String in def.advertise:
		var need_def := content.need(need_id)
		if need_def == null:
			continue
		var value := clampf(float(person.needs.get(need_id, 100.0)), 0.0, 100.0)
		var gain := minf(float(def.advertise[need_id]), 100.0 - value)
		total += urgency(value, need_def.urgency_weight) * gain
	return total
