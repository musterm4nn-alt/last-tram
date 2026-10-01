class_name Memory
extends RefCounted
## Something a person remembers (docs/design/people.md → "Memory"). Saved on the person;
## people are referenced by id. Salience fades each day (SocialSystem); the least salient
## memory is forgotten first when the list is full (Memories.CAP).

const EXPERIENCED: String = "experienced"
const WITNESSED: String = "witnessed"
const HEARD: String = "heard"

var tick: int = 0
## What happened, e.g. "joked_with", "insulted_by" (the interaction outcome that made it).
var kind: String = ""
## The people it is about, by id.
var subject_ids: Array[int] = []
## Where it happened (place id, "" if nowhere in particular).
var place_id: String = ""
## How it felt, −100..100.
var valence: int = 0
## How much it matters now, 0..100.
var salience: float = 50.0
## EXPERIENCED, WITNESSED or HEARD.
var source: String = EXPERIENCED
## Who told them, for HEARD memories (0 otherwise).
var source_id: int = 0


func to_dict() -> Dictionary:
	return {
		"tick": tick, "kind": kind, "subject_ids": subject_ids.duplicate(), "place_id": place_id,
		"valence": valence, "salience": salience, "source": source, "source_id": source_id,
	}


static func from_dict(d: Dictionary) -> Memory:
	var m := Memory.new()
	m.tick = int(d["tick"])
	m.kind = String(d["kind"])
	for id: Variant in d.get("subject_ids", []):
		m.subject_ids.append(int(id))
	m.place_id = String(d.get("place_id", ""))
	m.valence = clampi(int(d.get("valence", 0)), -100, 100)
	m.salience = clampf(float(d.get("salience", 0.0)), 0.0, 100.0)
	m.source = String(d.get("source", EXPERIENCED))
	m.source_id = int(d.get("source_id", 0))
	return m
