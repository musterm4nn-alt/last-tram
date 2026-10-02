class_name ContactsApp
extends RefCounted
## The phone's Contacts app (T-0063): the people the player knows (familiarity at least
## KNOWN), best friends first, each with a Call button. Pure helpers; Phone draws them.

## How well the player must know someone to have their number.
const KNOWN: float = 30.0


## Ids of the people the player knows, by the player's friendship (highest first), then id.
static func contacts(sim: Sim, player_id: int) -> Array[int]:
	var player := sim.world.get_person(player_id)
	var out: Array[int] = []
	if player == null:
		return out
	for r: Relationship in player.relationships.values():
		if r.familiarity >= KNOWN and sim.world.get_person(r.other_id) != null:
			out.append(r.other_id)
	out.sort_custom(func(a: int, b: int) -> bool:
		var fa := player.relationships[a].friendship
		var fb := player.relationships[b].friendship
		return fa > fb if fa != fb else a < b)
	return out


## "Mira Kovač · a friend" for a contact (how they see the player).
static func line(sim: Sim, player_id: int, other_id: int) -> String:
	var other := sim.world.get_person(other_id)
	return "%s · %s" % [other.full_name(), PersonInspector.relationship_label(Social.relationship(other, player_id))]
