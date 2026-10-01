class_name Moodlet
extends RefCounted
## A running moodlet on a person (saved): which MoodletDef, and the tick it ends.

var id: String = ""
var ends_tick: int = 0


func to_dict() -> Dictionary:
	return {"id": id, "ends_tick": ends_tick}


static func from_dict(d: Dictionary) -> Moodlet:
	var m := Moodlet.new()
	m.id = String(d["id"])
	m.ends_tick = int(d["ends_tick"])
	return m
