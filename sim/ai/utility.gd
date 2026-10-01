class_name Utility
extends RefCounted
## How much a person wants what an interaction advertises (docs/design/actions-and-autonomy.md
## → Autonomy). Pure functions, no state.

## Starting bias of mean social interactions: only dislike or a hot temper overcomes it.
const MEAN_PENALTY: float = -4.0
## Starting bias of romantic ones: only existing romance overcomes it.
const ROMANCE_PENALTY: float = -3.0
## A positive bias times this, times the share of Social still missing (0 when full).
const SOCIAL_BIAS_SCALE: float = 2.0


## ((100 - value) / 100)² × weight: 0 when the need is full, `weight` when it is empty.
## `value` is clamped to 0..100 first.
static func urgency(value: float, weight: float) -> float:
	var missing := (100.0 - clampf(value, 0.0, 100.0)) / 100.0
	return missing * missing * weight


## How much `person` feels like doing person-targeted `def` to `other`, on top of the need
## score (T-0039): friendly things grow with friendship and sociability; mean ones need dislike
## or a hot temper (and start at MEAN_PENALTY); romantic ones need romance. Positive bias
## shrinks as the person's Social fills up, so content people don't talk all day.
static func social_bias(person: Person, other: Person, def: InteractionDef) -> float:
	if def.social == null:
		return 0.0
	var bias := _raw_social_bias(person, other, def)
	if bias <= 0.0:
		return bias
	var wanting := (100.0 - clampf(float(person.needs.get("social", 100.0)), 0.0, 100.0)) / 100.0
	return bias * SOCIAL_BIAS_SCALE * wanting


static func _raw_social_bias(person: Person, other: Person, def: InteractionDef) -> float:
	var view := Social.relationship(person, other.id)
	var friendship := view.friendship if view != null else 0.0
	var romance := view.romance if view != null else 0.0
	var sociability := person.personality.get_axis("sociability")
	match def.social.kind:
		"friendly":
			return friendship / 25.0 + sociability / 50.0
		"mean":
			return MEAN_PENALTY - friendship / 15.0 + person.personality.get_axis("temper") / 40.0 - person.personality.get_axis("kindness") / 50.0
		"romantic":
			return ROMANCE_PENALTY + romance / 12.0 + friendship / 50.0
	return 0.0


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
