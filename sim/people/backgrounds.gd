class_name Backgrounds
extends RefCounted
## Starting a life from a background (T-0075; static, no state). SimFactory gives the player
## the background's money and job; apply() adds the rest once the town exists.

## How well the neighbours a background knows start out knowing the player (both ways).
const ACQUAINTANCE: Dictionary = {"familiarity": 35.0, "friendship": 10.0, "trust": 10.0}


## The background `id` names, or the content's default for "" or an unknown id.
static func of(content: ContentDB, id: String) -> BackgroundDef:
	var def := content.background(id)
	return def if def != null else content.background(content.default_background)


## The background's skills, neighbours (the first `knows` other residents in a shuffled id
## order, from the "background" stream), moodlet and record; Person.origin remembers it.
static func apply(sim: Sim, player: Person, def: BackgroundDef) -> void:
	player.origin = def.id
	player.record = def.record
	for skill_id: String in def.skills:
		player.skills[skill_id] = def.skills[skill_id] * sim.content.skill_rules.xp_per_level
	if not def.moodlet_id.is_empty():
		Social.add_moodlet(sim, player, def.moodlet_id)
	var ids: Array = []
	for id: int in sim.world.people.keys():
		var other: Person = sim.world.people[id]
		if id != player.id and other.household_id != player.household_id:
			ids.append(id)
	ids.sort()
	var rng := sim.rng.stream("background")
	for i: int in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = ids[i]
		ids[i] = ids[j]
		ids[j] = swap
	for id: int in ids.slice(0, def.knows):
		Social.set_values(player, id, ACQUAINTANCE, sim.clock.tick)
		Social.set_values(sim.world.people[id], player.id, ACQUAINTANCE, sim.clock.tick)
