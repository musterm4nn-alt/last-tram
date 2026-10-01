class_name Social
extends RefCounted
## Relationships, memories and moodlets (T-0037; static, no state). Everything changes
## through these functions, which clamp values and keep the lists capped.

## Most memories a person keeps; the least salient goes first.
const MEMORY_CAP: int = 60
## Relationships drift towards neutral after this many days without contact.
const DRIFT_AFTER_DAYS: int = 2
## Daily drift per value without contact (towards 0).
const DRIFT_PER_DAY: Dictionary = {"friendship": 1.0, "trust": 1.0, "romance": 1.0, "fear": 2.0, "familiarity": 0.5}
## Familiarity never drifts below this once people know each other well.
const FAMILIARITY_FLOOR: float = 20.0
## Memories lose this much salience per day and are forgotten at 0.
const SALIENCE_DECAY_PER_DAY: float = 5.0


## `person`'s view of `other_id`, or null if they have never met.
static func relationship(person: Person, other_id: int) -> Relationship:
	return person.relationships.get(other_id)


## `person`'s view of `other_id`, created (neutral) on first contact.
static func relationship_or_new(person: Person, other_id: int) -> Relationship:
	if not person.relationships.has(other_id):
		var r := Relationship.new()
		r.other_id = other_id
		person.relationships[other_id] = r
	return person.relationships[other_id]


## Adds `deltas` (value name -> amount) to `person`'s view of `other_id`, clamped, and marks
## the contact. Emits &"relationship_changed".
static func change(sim: Sim, person: Person, other_id: int, deltas: Dictionary) -> void:
	var r := relationship_or_new(person, other_id)
	for key: String in deltas:
		if not Relationship.RANGES.has(key):
			continue
		var bounds: Array = Relationship.RANGES[key]
		r.set(key, clampf(r.value(key) + float(deltas[key]), float(bounds[0]), float(bounds[1])))
	r.last_contact_tick = sim.clock.tick
	sim.emit_event(&"relationship_changed", {"person_id": person.id, "other_id": other_id})


## Sets `person`'s view of `other_id` (household members at a new game; no event).
static func set_values(person: Person, other_id: int, values: Dictionary, tick: int) -> void:
	var r := relationship_or_new(person, other_id)
	for key: String in values:
		var bounds: Array = Relationship.RANGES[key]
		r.set(key, clampf(float(values[key]), float(bounds[0]), float(bounds[1])))
	r.last_contact_tick = tick


## Adds a memory (at the person's current place), forgetting the least salient one when the
## list is full. Emits &"memory_added".
static func remember(sim: Sim, person: Person, kind: String, subject_ids: Array[int], valence: int,
		salience: float, source: String = Memory.EXPERIENCED, source_id: int = 0) -> Memory:
	var m := Memory.new()
	m.tick = sim.clock.tick
	m.kind = kind
	m.subject_ids = subject_ids.duplicate()
	var place := sim.content.place_at(person.cell())
	m.place_id = place.id if place != null else ""
	m.valence = clampi(valence, -100, 100)
	m.salience = clampf(salience, 0.0, 100.0)
	m.source = source
	m.source_id = source_id
	person.memories.append(m)
	if person.memories.size() > MEMORY_CAP:
		var weakest := 0
		for i: int in person.memories.size():
			if person.memories[i].salience < person.memories[weakest].salience:
				weakest = i
		person.memories.remove_at(weakest)
	sim.emit_event(&"memory_added", {"person_id": person.id, "kind": kind})
	return m


## The memories `person` has about `subject_id`, most salient first.
static func memories_about(person: Person, subject_id: int) -> Array[Memory]:
	var out: Array[Memory] = []
	for m: Memory in person.memories:
		if m.subject_ids.has(subject_id):
			out.append(m)
	out.sort_custom(func(a: Memory, b: Memory) -> bool: return a.salience > b.salience)
	return out


## Starts (or restarts) moodlet `moodlet_id` on `person`. Unknown ids are ignored. Emits
## &"moodlet_added".
static func add_moodlet(sim: Sim, person: Person, moodlet_id: String) -> void:
	var def := sim.content.moodlet(moodlet_id)
	if def == null:
		return
	var ends := sim.clock.tick + int(def.duration_hours * 60.0) * SimClock.STEPS_PER_GAME_MINUTE
	for m: Moodlet in person.moodlets:
		if m.id == moodlet_id:
			m.ends_tick = ends
			sim.emit_event(&"moodlet_added", {"person_id": person.id, "moodlet": moodlet_id})
			return
	var m := Moodlet.new()
	m.id = moodlet_id
	m.ends_tick = ends
	person.moodlets.append(m)
	sim.emit_event(&"moodlet_added", {"person_id": person.id, "moodlet": moodlet_id})


## The sum of the person's moodlet values (unknown ids count 0).
static func moodlet_total(person: Person, content: ContentDB) -> float:
	var total := 0.0
	for m: Moodlet in person.moodlets:
		var def := content.moodlet(m.id)
		if def != null:
			total += def.value
	return total
