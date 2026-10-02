class_name DiscoveryDef
extends RefCounted
## A secret of the town (T-0067, docs/design/discoveries.md): a clue to learn, a place and a
## time window to uncover it in, and effects. Loaded from data/discoveries/ by DiscoveryLoader.

var id: String = ""
var name: String = ""
## The lead shown in the notebook: what to look for and roughly where.
var clue: String = ""
## The PlaceDef it belongs to.
var place_id: String = ""
## Game minutes of the day (0..1439) it can be uncovered in; to < from wraps past midnight,
## from == to means all day.
var from_minute: int = 0
var to_minute: int = 0
## The floor (Vector3i.z) it is on.
var level: int = 0
## True: searching uncovers it only with the clue; false: searching there finds the clue.
var clue_required: bool = true
## Trust a person needs in someone to share the clue with them; -1: nobody shares it.
var share_trust: int = -1
var effects: Array[DiscoveryEffect] = []
## Optional: the place whose residents or staff know the clue in a new town (T-0070).
var known_at_start: String = ""
## Optional scene requested for the player on uncovering it (like a presentation).
var scene_id: String = ""


## True if `minute` (0..1439) is inside the window.
func in_window(minute: int) -> bool:
	if from_minute == to_minute:
		return true
	if from_minute < to_minute:
		return minute >= from_minute and minute < to_minute
	return minute >= from_minute or minute < to_minute
