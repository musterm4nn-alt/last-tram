class_name Conversations
extends RefCounted
## Person-targeted interactions (T-0038; static, no state): who is available to talk to,
## where to stand, how likely an interaction lands, and what its outcome does to both people.
## Outcomes are rolled with the "social" random stream (docs/design/social-and-dialogue.md).

## How long someone keeps walking after a person who moves away, in game minutes.
const ROUTE_LIMIT_MINUTES: int = 10
## Salience of a new social memory: |valence| plus this.
const MEMORY_SALIENCE: float = 20.0


## True if `target` can be talked to: they exist, are awake and are not walking somewhere.
static func available(sim: Sim, target: Person) -> bool:
	if target == null or not target.path.is_empty() or target.move_intent != Vector2.ZERO:
		return false
	if Jobs.hidden(sim, target):
		return false  # at work, out of sight (T-0059)
	if target.action_queue.is_empty() or target.action_queue[0].state != Action.PERFORMING:
		return true
	var def := sim.content.interaction(target.action_queue[0].interaction_id)
	return def == null or def.routine != "sleep"


## True if the two stand on neighbouring cells (8 directions) of the same level.
static func adjacent(a: Person, b: Person) -> bool:
	var ca := a.cell()
	var cb := b.cell()
	return ca != cb and ca.z == cb.z and absi(ca.x - cb.x) <= 1 and absi(ca.y - cb.y) <= 1


## The shortest path to a free walkable cell next to `target` (straight neighbours first), or
## [] if none can be reached.
static func route_to(sim: Sim, actor: Person, target: Person) -> Array[Vector3i]:
	var best: Array[Vector3i] = []
	var taken: Dictionary[Vector3i, bool] = {}
	for person: Person in sim.world.people.values():
		if person.id != actor.id:
			taken[person.cell()] = true
	var centre := target.cell()
	for offset: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var cell := centre + Vector3i(offset.x, offset.y, 0)
		if taken.has(cell) or not sim.world.grid.is_walkable(cell):
			continue
		var path := sim.nav.find_path(actor.cell(), cell)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best


## The chance (0..1) that `def` lands when `actor` does it to `target`: a logistic of the
## interaction's base, the target's view of the actor, the target's mood and personality, and
## how urgent the target's own needs are.
static func acceptance(sim: Sim, actor: Person, target: Person, def: InteractionDef) -> float:
	var social := def.social
	var view := Social.relationship(target, actor.id)
	var friendship := view.friendship if view != null else 0.0
	var familiarity := view.familiarity if view != null else 0.0
	var romance := view.romance if view != null else 0.0
	var x := social.base + (Mood.compute(target, sim.content) - 20.0) / 40.0
	if social.kind != "mean":  # a charming actor lands friendly and romantic moves more often (T-0071)
		x += Skills.level(sim.content, actor, "charisma") * sim.content.skill_rules.charisma_per_level
	match social.kind:
		"friendly":
			x += friendship / 25.0 + familiarity / 100.0
			x += (target.personality.get_axis("kindness") + target.personality.get_axis("sociability")) / 200.0
		"romantic":
			x += friendship / 50.0 + romance / 25.0 + (familiarity - 30.0) / 50.0
		"mean":
			# Insults from a friend hurt less; hot heads hit harder, the brave shrug more.
			x += -friendship / 50.0 + (actor.personality.get_axis("temper") - target.personality.get_axis("bravery")) / 200.0
	var lowest := 100.0
	for need_id: String in target.needs:
		lowest = minf(lowest, target.needs[need_id])
	x -= maxf(0.0, 30.0 - lowest) / 15.0
	return 1.0 / (1.0 + exp(-x))


## Rolls the outcome of `def` (stream "social"), applies it to both people and emits
## &"social_exchange". Returns the outcome id.
static func resolve(sim: Sim, actor: Person, target: Person, def: InteractionDef) -> String:
	var chance := acceptance(sim, actor, target, def)
	var outcome_id := "success" if sim.rng.stream("social").randf() < chance else "fail"
	var outcome: SocialOutcomeDef = def.social.outcomes[outcome_id]
	Social.change(sim, actor, target.id, outcome.actor)
	Social.change(sim, target, actor.id, outcome.target)
	if not outcome.actor_moodlet.is_empty():
		Social.add_moodlet(sim, actor, outcome.actor_moodlet)
	if not outcome.target_moodlet.is_empty():
		Social.add_moodlet(sim, target, outcome.target_moodlet)
	for need_id: String in outcome.target_needs:
		target.needs[need_id] = clampf(float(target.needs.get(need_id, 0.0)) + outcome.target_needs[need_id], 0.0, 100.0)
	var salience := absf(outcome.valence) + MEMORY_SALIENCE
	Social.remember(sim, actor, outcome.memory, [target.id] as Array[int], outcome.valence, salience)
	Social.remember(sim, target, outcome.memory, [actor.id] as Array[int], outcome.valence, salience)
	if outcome_id == "success" and def.social.kind == "friendly":
		Discoveries.share_clues(sim, actor, target)
	var place := sim.content.place_at(actor.cell())
	sim.emit_event(&"social_exchange", {
		"actor_id": actor.id,
		"target_id": target.id,
		"interaction_id": def.id,
		"outcome": outcome_id,
		"place_id": place.id if place != null else "",
		"chance": chance,
	})
	return outcome_id


## Turns `person` to look at `other` (one of the four directions).
static func face(person: Person, other: Person) -> void:
	var d := other.pos - person.pos
	if d == Vector2.ZERO:
		return
	if absf(d.x) > absf(d.y):
		person.facing = Vector2.RIGHT if d.x > 0.0 else Vector2.LEFT
	else:
		person.facing = Vector2.DOWN if d.y > 0.0 else Vector2.UP
