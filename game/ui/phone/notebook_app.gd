class_name NotebookApp
extends RefCounted
## The player's notebook (T-0068 notices; the phone app comes with T-0069): what they learn
## and find, in words. Pure helpers.


## The notice for a discovery event about the player ("" otherwise): a clue heard or found,
## a find, or a search that turned up nothing.
static func notice(event: Dictionary, sim: Sim) -> String:
	var data: Dictionary = event.get("data", {})
	if sim == null or int(data.get("person_id", -1)) != sim.world.player_id:
		return ""
	var def := sim.content.discovery(String(data.get("discovery_id", "")))
	var place := sim.content.place(def.place_id) if def != null else null
	match event.get("type"):
		&"clue_learned":
			if place == null:
				return ""
			if String(data.get("source", "")) == "talk":
				return "You heard something about %s." % place.name
			return "A lead: something about %s. (Notebook)" % place.name
		&"discovery_uncovered":
			return "You found something: %s." % def.name if def != null else ""
		&"searched":
			if String(data.get("result", "")) == "nothing":
				return "Nothing here."
	return ""
