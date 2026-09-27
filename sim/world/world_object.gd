class_name WorldObject
extends RefCounted
## One object in the town (runtime entity, saved). Its definition (size, slots...)
## lives in ContentDB; only the id, def id, origin cell and rotation are stored here.

var id: int = 0
var def_id: String = ""
var origin: Vector3i = Vector3i.ZERO
## Clockwise quarter turns, 0..3.
var rotation: int = 0


## Footprint cells in the world. Empty if the def id is unknown.
func cells(content: ContentDB) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var def := content.object_def(def_id)
	if def == null:
		return out
	for offset: Vector2i in def.footprint(rotation):
		out.append(Vector3i(origin.x + offset.x, origin.y + offset.y, origin.z))
	return out


## How many use slots this object has (0 if the def id is unknown).
func slot_count(content: ContentDB) -> int:
	var def := content.object_def(def_id)
	if def == null:
		return 0
	return def.use_slots.size()


## World cell of use slot `index` (same level as the origin).
func slot_cell(content: ContentDB, index: int) -> Vector3i:
	var def := content.object_def(def_id)
	if def == null or index < 0 or index >= def.use_slots.size():
		return origin
	var def_size := def.size
	var slot: UseSlotDef = def.use_slots[index]
	var rotated := ObjectDef.rotate_offset(slot.offset, def_size, rotation)
	return Vector3i(origin.x + rotated.x, origin.y + rotated.y, origin.z)


## Direction a person on use slot `index` looks while using the object.
func slot_facing(content: ContentDB, index: int) -> Vector2i:
	var def := content.object_def(def_id)
	if def == null or index < 0 or index >= def.use_slots.size():
		return Vector2i.ZERO
	var slot: UseSlotDef = def.use_slots[index]
	return ObjectDef.rotate_facing(slot.facing, rotation)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"def_id": def_id,
		"origin": Ser.cell(origin),
		"rotation": rotation,
	}


static func from_dict(d: Dictionary) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = int(d["id"])
	obj.def_id = String(d["def_id"])
	obj.origin = Ser.to_cell(d["origin"])
	obj.rotation = int(d["rotation"])
	return obj
