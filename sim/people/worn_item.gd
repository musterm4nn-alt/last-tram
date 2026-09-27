class_name WornItem
extends RefCounted
## One piece of clothing someone has on: which item and in which colour.
## Owned by an Outfit (slot -> WornItem); saved as {"item": id, "colour": id}.


var clothing_id: String = ""
var colour: String = ""


func _init(p_clothing_id: String = "", p_colour: String = "") -> void:
	clothing_id = p_clothing_id
	colour = p_colour


func copy() -> WornItem:
	return WornItem.new(clothing_id, colour)


func to_dict() -> Dictionary:
	return {"item": clothing_id, "colour": colour}


static func from_dict(d: Dictionary) -> WornItem:
	var item_id := String(d.get("item", d.get("clothing_id", "")))
	return WornItem.new(item_id, String(d.get("colour", "")))
