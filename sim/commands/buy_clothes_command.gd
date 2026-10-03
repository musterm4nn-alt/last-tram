class_name BuyClothesCommand
extends Command
## The clothes shop screen (T-0073): the person buys an item in a colour (Shopping.buy_clothes).
## Emits &"clothes_bought" {person_id, item, colour, price} or &"clothes_refused" {person_id,
## item, reason}. Ignored for an unknown person.

var person_id: int = 0
var item: String = ""
var colour: String = ""


func _init(p_person_id: int = 0, p_item: String = "", p_colour: String = "") -> void:
	person_id = p_person_id
	item = p_item
	colour = p_colour


func type_id() -> String:
	return "buy_clothes"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	var reason := Shopping.buy_clothes(sim, person, item, colour)
	if not reason.is_empty():
		sim.emit_event(&"clothes_refused", {"person_id": person_id, "item": item, "reason": reason})
		return
	person.last_input_tick = sim.clock.tick
	sim.emit_event(&"clothes_bought", {"person_id": person_id, "item": item, "colour": colour, "price": sim.content.clothing_def(item).price})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "item": item, "colour": colour}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	item = String(d["item"])
	colour = String(d["colour"])
