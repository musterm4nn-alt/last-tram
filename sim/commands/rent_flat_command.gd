class_name RentFlatCommand
extends Command
## The phone's Housing app (T-0066): the person's household rents an empty flat
## (Moving.rent_flat). A refusal emits &"rent_flat_refused" {person_id, lot_id, reason}.
## Ignored for an unknown person.

var person_id: int = 0
var lot_id: int = 0


func _init(p_person_id: int = 0, p_lot_id: int = 0) -> void:
	person_id = p_person_id
	lot_id = p_lot_id


func type_id() -> String:
	return "rent_flat"


func apply(sim: Sim) -> void:
	var person := sim.world.get_person(person_id)
	if person == null:
		return
	person.last_input_tick = sim.clock.tick
	var reason := Moving.rent_flat(sim, person, sim.world.lots.get(lot_id))
	if not reason.is_empty():
		sim.emit_event(&"rent_flat_refused", {"person_id": person_id, "lot_id": lot_id, "reason": reason})


func to_dict() -> Dictionary:
	return {"person_id": person_id, "lot_id": lot_id}


func load_dict(d: Dictionary) -> void:
	person_id = int(d["person_id"])
	lot_id = int(d["lot_id"])
