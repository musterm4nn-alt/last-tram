class_name Discoveries
extends RefCounted
## Learning clues and uncovering the town's secrets (T-0067, docs/design/discoveries.md;
## static, no state). What people know lives in Person.known_clues / Person.discoveries, the
## world-once rewards in World.looted_discoveries.

## How well you know the people a contact effect gives you (enough for their number).
const CONTACT_FAMILIARITY: float = 30.0
## A find's memory: its valence and salience.
const MEMORY_VALENCE: int = 20
const MEMORY_SALIENCE: float = 60.0


## True when `def` can be uncovered by `person` now at `place_id`: the right place, level and
## time, and not found yet. (Whether the clue is needed is the caller's business.)
static func eligible(sim: Sim, person: Person, def: DiscoveryDef, place_id: String) -> bool:
	return def.place_id == place_id and person.level == def.level and def.in_window(sim.clock.minute_of_day()) \
		and not person.discoveries.has(def.id)


## `person` learns the clue of discovery `id` (from `source`: "search", "talk", "read"...;
## `source_id` the person or object it came from). False (nothing happens) for an unknown
## id, or a clue they know already or a discovery they've found. Emits &"clue_learned"
## {person_id, discovery_id, source, source_id}.
static func learn_clue(sim: Sim, person: Person, id: String, source: String, source_id: int = 0) -> bool:
	if sim.content.discovery(id) == null or person.known_clues.has(id) or person.discoveries.has(id):
		return false
	person.known_clues.append(id)
	person.known_clues.sort()
	sim.emit_event(&"clue_learned", {"person_id": person.id, "discovery_id": id, "source": source, "source_id": source_id})
	return true


## `person` uncovers discovery `id`: it moves from their clues to their finds, its effects
## apply (money only the first time in the world), they remember it (a memory of kind `id`
## at its place), the player gets its scene, and &"discovery_uncovered" {person_id,
## discovery_id, place_id} goes out. False for an unknown id or one they found already.
static func uncover(sim: Sim, person: Person, id: String) -> bool:
	var def := sim.content.discovery(id)
	if def == null or person.discoveries.has(id):
		return false
	var at := person.known_clues.find(id)
	if at >= 0:
		person.known_clues.remove_at(at)
	person.discoveries.append(id)
	person.discoveries.sort()
	for effect: DiscoveryEffect in def.effects:
		_apply(sim, person, def, effect)
	var none: Array[int] = []
	var memory := Social.remember(sim, person, id, none, MEMORY_VALENCE, MEMORY_SALIENCE)
	if memory != null:
		memory.place_id = def.place_id
	if not def.scene_id.is_empty() and person.id == sim.world.player_id:
		sim.emit_event(&"scene_requested", {"scene_id": def.scene_id, "actor_id": person.id, "target_id": 0, "place_id": def.place_id})
	sim.emit_event(&"discovery_uncovered", {"person_id": person.id, "discovery_id": id, "place_id": def.place_id})
	return true


static func _apply(sim: Sim, person: Person, def: DiscoveryDef, effect: DiscoveryEffect) -> void:
	match effect.kind:
		DiscoveryEffect.MONEY:
			if not sim.world.looted_discoveries.has(def.id):
				sim.world.looted_discoveries.append(def.id)
				sim.world.looted_discoveries.sort()
				Money.earn(sim, person, effect.cents, "found", Money.CASH, def.id)
		DiscoveryEffect.MOODLET:
			Social.add_moodlet(sim, person, effect.moodlet_id)
		DiscoveryEffect.CONTACT:
			for other: Person in people_of(sim, effect.place_id):
				if other.id == person.id:
					continue
				var known := Social.relationship(person, other.id)
				var familiarity := known.familiarity if known != null else 0.0
				if familiarity < CONTACT_FAMILIARITY:
					Social.change(sim, person, other.id, {"familiarity": CONTACT_FAMILIARITY - familiarity})
		# NOTE and UNLOCK change nothing here: the notebook shows notes, and Requirements
		# reads Person.discoveries for interactions that require one.


## The people of a place, by id: those who live there (its lot is their home) and those
## whose job is there.
static func people_of(sim: Sim, place_id: String) -> Array[Person]:
	var lot := Lots.by_place(sim.world, place_id)
	var ids: Array = sim.world.people.keys()
	ids.sort()
	var out: Array[Person] = []
	for id: int in ids:
		var person: Person = sim.world.people[id]
		var job := sim.content.job(person.job.job_id) if person.job != null else null
		if (lot != null and person.home_lot_id == lot.id) or (job != null and job.place_id == place_id):
			out.append(person)
	return out
