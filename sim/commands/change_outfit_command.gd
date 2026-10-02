class_name ChangeOutfitCommand
extends Command
## The wardrobe screen (T-0072): the person puts on `outfit` (slot -> {item, colour}) and, with
## `save_as` (one of Wardrobe.OUTFIT_NAMES), saves it under that name. They must stand at a
## wardrobe in their home and own every piece (Wardrobe.problems). Emits &"outfit_changed"
## {person_id, saved_as}, or &"outfit_refused" {person_id, reason: "not_at_wardrobe" |
## "not_owned" | "bad_name"}. Ignored for an unknown person.

var person_id: int = 0
var outfit: Dictionary = {}
var save_as: String = ""


func _init(p_person_id: int = 0, p_outfit: Dictionary = {}, p_save_as: String = "") -> void:
	person_id = p_person_id
	outfit = p_outfit
	save_as = p_save_as


func type_id() -> String:
	return "change_outfit"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	var wanted := Outfit.from_dict(outfit)
	var reason := ""
	if not Wardrobe.at_wardrobe(sim, person):
		reason = "not_at_wardrobe"
	elif not Wardrobe.problems(sim, person, wanted).is_empty():
		reason = "not_owned"
	elif not save_as.is_empty() and not Wardrobe.OUTFIT_NAMES.has(save_as):
		reason = "bad_name"
	if not reason.is_empty():
		sim.emit_event(&"outfit_refused", {"person_id": person_id, "reason": reason})
		return
	person.last_input_tick = sim.clock.tick
	person.outfit = wanted
	if not save_as.is_empty():
		person.outfits[save_as] = wanted.copy()
	sim.emit_event(&"outfit_changed", {"person_id": person_id, "saved_as": save_as})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "outfit": outfit.duplicate(true), "save_as": save_as}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	outfit = (d["outfit"] as Dictionary).duplicate(true) if d.get("outfit") is Dictionary else {}
	save_as = String(d.get("save_as", ""))
