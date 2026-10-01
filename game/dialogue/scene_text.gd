class_name SceneText
extends RefCounted
## Fills a scene page's {placeholders} (T-0043): {actor}, {target} (display names), {place}
## (the place's name), and {actor.they} / {actor.them} / {actor.their} / {actor.themself}
## (and the same for target) from each person's pronoun set. Unknown people read as
## "someone". A sentence that starts with a pronoun gets a capital letter.


static func fill(text: String, request: Dictionary, sim: Sim) -> String:
	var out := text
	for role: String in ["actor", "target"]:
		var person := sim.world.get_person(int(request.get(role + "_id", 0))) if sim != null else null
		var pronouns: PronounSet = sim.content.appearance.pronouns.get(person.pronouns) if person != null else null
		var forms := {
			"they": pronouns.subject if pronouns != null else "they",
			"them": pronouns.object if pronouns != null else "them",
			"their": pronouns.possessive if pronouns != null else "their",
			"themself": pronouns.reflexive if pronouns != null else "themself",
		}
		for form: String in forms:
			out = out.replace("{%s.%s}" % [role, form], forms[form])
		out = out.replace("{%s}" % role, person.display_name() if person != null else "someone")
	var place := sim.content.place(String(request.get("place_id", ""))) if sim != null else null
	out = out.replace("{place}", place.name if place != null else "here")
	if not out.is_empty():
		out = out[0].to_upper() + out.substr(1)
	return out
