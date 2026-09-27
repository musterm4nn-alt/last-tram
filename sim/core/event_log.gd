class_name EventLog
extends RefCounted
## Output channel of the sim: "something happened" notices for the view, UI and tests.
## The sim never reads its own events back, and events are not saved. After loading a
## save, views rebuild from world state instead of replaying events.
##
## An event is a Dictionary: {"type": StringName, "tick": int, "data": Dictionary}.

const RECENT_LIMIT: int = 30

var _pending: Array[Dictionary] = []
## The last RECENT_LIMIT events, newest last (for the debug overlay).
var recent: Array[Dictionary] = []


func push(type: StringName, tick: int, data: Dictionary = {}) -> void:
	var event := {"type": type, "tick": tick, "data": data}
	_pending.append(event)
	recent.append(event)
	if recent.size() > RECENT_LIMIT:
		recent.pop_front()


## Returns and clears everything pushed since the last drain.
func drain() -> Array[Dictionary]:
	var out := _pending
	_pending = []
	return out
