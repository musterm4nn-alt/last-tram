class_name ObjectPlacement
extends RefCounted
## One authored object placement from a district's objects.json (content, not saved).
## `cell` is in WORLD coordinates (the district origin is already applied).

var def_id: String = ""
var cell: Vector3i = Vector3i.ZERO
## Clockwise quarter turns, 0..3.
var rotation: int = 0
