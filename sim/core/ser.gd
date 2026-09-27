class_name Ser
extends RefCounted
## Helpers for to_dict()/from_dict(). Saves are JSON, and JSON has no ints, vectors or
## int keys: every number comes back as a float. Always convert explicitly on load:
##     id = int(d["id"])
##     pos = Ser.to_vec2(d["pos"])


static func vec2(v: Vector2) -> Array:
	return [v.x, v.y]


static func to_vec2(value: Variant) -> Vector2:
	var a: Array = value
	return Vector2(float(a[0]), float(a[1]))


static func cell(c: Vector3i) -> Array:
	return [c.x, c.y, c.z]


static func to_cell(value: Variant) -> Vector3i:
	var a: Array = value
	return Vector3i(int(a[0]), int(a[1]), int(a[2]))


static func vec2i(v: Vector2i) -> Array:
	return [v.x, v.y]


static func to_vec2i(value: Variant) -> Vector2i:
	var a: Array = value
	return Vector2i(int(a[0]), int(a[1]))


## Canonical JSON text for saves and comparisons: sorted keys, full float precision.
static func to_json(data: Variant, pretty: bool = true) -> String:
	return JSON.stringify(data, "\t" if pretty else "", true, true)
