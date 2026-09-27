class_name Mood
extends RefCounted
## Mood from needs (M1). Pure and not saved: mood is recomputed whenever needed.
## Moodlets (M2) will add to the value computed here.


## Mood from low needs only: starts at 20, each need below 50 subtracts
## ((50 - v) / 50)^2 * 30 * urgency_weight. Result is clamped to -100..100.
static func compute(person: Person, content: ContentDB) -> float:
	var mood: float = 20.0
	for need_def: NeedDef in content.needs:
		var value: float = float(person.needs.get(need_def.id, need_def.start))
		if value < 50.0:
			var shortfall: float = (50.0 - value) / 50.0
			mood -= shortfall * shortfall * 30.0 * need_def.urgency_weight
	return clampf(mood, -100.0, 100.0)


## Display label for a mood value.
static func label(mood_value: float) -> String:
	if mood_value >= 20.0:
		return "Fine"
	if mood_value >= 0.0:
		return "Okay"
	if mood_value >= -40.0:
		return "Uneasy"
	return "Miserable"
