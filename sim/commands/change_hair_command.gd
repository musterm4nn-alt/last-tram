class_name ChangeHairCommand
extends Command
## The barber screen (T-0073): a new hair style and colour (Shopping.change_hair), at the
## barber chair. Emits &"hair_changed" {person_id} or &"hair_refused" {person_id, reason}.
## Ignored for an unknown person.

var person_id: int = 0
var style: String = ""
var colour: String = ""


func _init(p_person_id: int = 0, p_style: String = "", p_colour: String = "") -> void:
	person_id = p_person_id
	style = p_style
	colour = p_colour


func type_id() -> String:
	return "change_hair"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	var reason := Shopping.change_hair(sim, person, style, colour)
	if not reason.is_empty():
		sim.emit_event(&"hair_refused", {"person_id": person_id, "reason": reason})
		return
	person.last_input_tick = sim.clock.tick
	sim.emit_event(&"hair_changed", {"person_id": person_id})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "style": style, "colour": colour}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	style = String(d["style"])
	colour = String(d["colour"])
