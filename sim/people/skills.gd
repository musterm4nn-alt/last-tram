class_name Skills
extends RefCounted
## Getting better with practice (T-0071; static, no state). XP lives in Person.skills
## (skill id -> XP, saved); levels and their effects come from data/skills.json.


## The person's level in `skill_id`: XP / xp_per_level, at most max_level.
static func level(content: ContentDB, person: Person, skill_id: String) -> int:
	if person == null or skill_id.is_empty():
		return 0
	var rules := content.skill_rules
	return mini(rules.max_level, int(float(person.skills.get(skill_id, 0.0)) / rules.xp_per_level))


## Adds `xp` to the skill; a new level emits &"skill_up" {person_id, skill_id, level}.
static func gain(sim: Sim, person: Person, skill_id: String, xp: float) -> void:
	if xp <= 0.0 or sim.content.skill(skill_id) == null:
		return
	var before := level(sim.content, person, skill_id)
	person.skills[skill_id] = float(person.skills.get(skill_id, 0.0)) + xp
	var after := level(sim.content, person, skill_id)
	if after > before:
		sim.emit_event(&"skill_up", {"person_id": person.id, "skill_id": skill_id, "level": after})


## One minute of practice: the interaction's skill_xp (per hour) / 60.
static func practise(sim: Sim, person: Person, def: InteractionDef) -> void:
	for skill_id: String in def.skill_xp:
		gain(sim, person, skill_id, def.skill_xp[skill_id] / 60.0)


## How much an interaction's finish_needs grow with its finish_skill: 1 + level × bonus.
static func finish_factor(content: ContentDB, person: Person, def: InteractionDef) -> float:
	return 1.0 + level(content, person, def.finish_skill) * content.skill_rules.finish_bonus_per_level


## "Cooking 3, Charisma 1" for the skills at level 1 or more, in content order; "" for none.
static func text(content: ContentDB, person: Person) -> String:
	var parts := PackedStringArray()
	for def: SkillDef in content.skills.values():
		var at := level(content, person, def.id)
		if at >= 1:
			parts.append("%s %d" % [def.name, at])
	return ", ".join(parts)
