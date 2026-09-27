class_name Action
extends RefCounted
## One interaction a person queued or is performing. Saved inside
## Person.action_queue; the front action (index 0) is the current one.
## States: queued -> performing -> done (popped). T-0007 adds routing between
## queued and performing.

const QUEUED: String = "queued"
const ROUTING: String = "routing"
const PERFORMING: String = "performing"

var interaction_id: String = ""
var target_id: int = 0
## Use slot the person performs on, or -1 before it starts.
var slot_index: int = -1
var state: String = QUEUED
## Game minutes spent performing so far.
var minutes_done: int = 0
## Tick the action started performing, or -1 before it starts.
var started_tick: int = -1


func _init(p_interaction_id: String = "", p_target_id: int = 0) -> void:
	interaction_id = p_interaction_id
	target_id = p_target_id


func to_dict() -> Dictionary:
	return {
		"interaction_id": interaction_id,
		"target_id": target_id,
		"slot_index": slot_index,
		"state": state,
		"minutes_done": minutes_done,
		"started_tick": started_tick,
	}


static func from_dict(d: Dictionary) -> Action:
	var action := Action.new()
	action.interaction_id = String(d.get("interaction_id", ""))
	action.target_id = int(d.get("target_id", 0))
	action.slot_index = int(d.get("slot_index", -1))
	action.state = String(d.get("state", QUEUED))
	action.minutes_done = int(d.get("minutes_done", 0))
	action.started_tick = int(d.get("started_tick", -1))
	return action
