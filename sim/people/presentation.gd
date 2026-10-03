class_name Presentation
extends RefCounted
## How a person comes across (T-0074; derived, never saved): washed, in clean clothes, and
## dressed for the occasion. Job interviews use it (Hiring.chance).


## A score around 0 (logit-like, added to chances): (hygiene − 50) / 200, minus the worn
## clothes' dirt / 250, minus 0.1 per step of formality away from `formality` (the job's).
static func of(sim: Sim, person: Person, formality: float) -> float:
	var x := (float(person.needs.get("hygiene", 50.0)) - 50.0) / 200.0
	x -= Laundry.worn_dirt(person) / 250.0
	x -= 0.1 * absf(Hiring.outfit_formality(sim.content, person) - formality)
	return x
