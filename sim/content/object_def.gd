class_name ObjectDef
extends RefCounted
## One kind of world object (fridge, bed, sofa...). Defined in data/objects/*.json.
## `size` is the footprint [width, height] in cells at rotation 0. The footprint is
## the offsets (0..w-1, 0..h-1) from the origin (top-left). `use_slots` are cells
## next to the object where a person stands to use it (sim position stays on the
## slot). Every M1 object blocks movement; `blocks_movement` exists for later
## non-blocking objects (rugs).

var id: String = ""
var name: String = ""
## Footprint size at rotation 0 (both components >= 1).
var size: Vector2i = Vector2i.ONE
var blocks_movement: bool = true
var blocks_sight: bool = false
## Gameplay tags ("bed", "seat", "fridge"...), used by later interaction content.
var tags: PackedStringArray = PackedStringArray()
var use_slots: Array[UseSlotDef] = []
## Price in euro cents.
var price: int = 0
## Colour of the placeholder tile (view) and debug tools. Not real art.
var debug_color: Color = Color.MAGENTA


## Footprint cells as local offsets for the given rotation (0..3, clockwise).
func footprint(rotation: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in size.y:
		for x: int in size.x:
			out.append(ObjectDef.rotate_offset(Vector2i(x, y), size, rotation))
	return out


## Clockwise quarter turns (w/h = size at rotation 0). See T-0001 for the table.
static func rotate_offset(offset: Vector2i, size: Vector2i, rotation: int) -> Vector2i:
	match posmod(rotation, 4):
		1:
			return Vector2i(size.y - 1 - offset.y, offset.x)
		2:
			return Vector2i(size.x - 1 - offset.x, size.y - 1 - offset.y)
		3:
			return Vector2i(offset.y, size.x - 1 - offset.x)
		_:
			return offset


## Rotates a facing vector with the same clockwise quarter turns.
static func rotate_facing(facing: Vector2i, rotation: int) -> Vector2i:
	match posmod(rotation, 4):
		1:
			return Vector2i(-facing.y, facing.x)
		2:
			return Vector2i(-facing.x, -facing.y)
		3:
			return Vector2i(facing.y, -facing.x)
		_:
			return facing
