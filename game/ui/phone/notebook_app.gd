class_name NotebookApp
extends RefCounted
## The phone's Notebook app (T-0069; notices since T-0068): what the player learned and found,
## in words. Pure helpers; Phone draws the lines.


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


## The Notebook app's lines (T-0069): "Leads" (clues known, not yet followed up: the place
## and the clue) and "Finds" (what was uncovered and what it gave), each in id order.
static func lines(sim: Sim, player_id: int) -> PackedStringArray:
	var out := PackedStringArray()
	var person := sim.world.get_person(player_id)
	if person == null:
		return out
	out.append("Leads")
	if person.known_clues.is_empty():
		out.append("No leads yet. Talk to people, read notices, look around.")
	for id: String in person.known_clues:
		var def := sim.content.discovery(id)
		if def != null:
			out.append("%s: %s" % [sim.content.place(def.place_id).name, def.clue])
	out.append("")
	out.append("Finds")
	if person.discoveries.is_empty():
		out.append("Nothing yet.")
	for id: String in person.discoveries:
		var def := sim.content.discovery(id)
		if def == null:
			continue
		out.append("%s (%s)" % [def.name, sim.content.place(def.place_id).name])
		for effect: DiscoveryEffect in def.effects:
			var text := effect_text(sim, effect)
			if not text.is_empty():
				out.append("  " + text)
	return out


## What an effect gave, in words ("" for a moodlet: you felt it).
static func effect_text(sim: Sim, effect: DiscoveryEffect) -> String:
	match effect.kind:
		DiscoveryEffect.NOTE:
			return effect.text
		DiscoveryEffect.MONEY:
			return "Found %s" % Money.format(effect.cents)
		DiscoveryEffect.CONTACT:
			return "You know the people at %s now" % sim.content.place(effect.place_id).name
		DiscoveryEffect.UNLOCK:
			var interaction := sim.content.interaction(effect.interaction_id)
			return "You can now: %s" % (interaction.name if interaction != null else effect.interaction_id)
	return ""
