class_name UseSlotDef
extends RefCounted
## One place where a person stands to use an object, plus the direction they face.
## `offset` is relative to the object's origin at rotation 0 and may lie outside
## the footprint. `facing` is a unit cardinal vector (the direction the person looks).

var offset: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.ZERO
