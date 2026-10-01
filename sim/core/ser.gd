class_name Ser
extends RefCounted
## Helpers for to_dict()/from_dict(). Saves are JSON, and JSON has no ints, vectors or
## int keys: every number comes back as a float. Always convert explicitly on load:
##     id = int(d["id"])
##     pos = Ser.to_vec2(d["pos"])
##
## Godot's JSON parser reads some decimals back a bit off (about one float in ten), so
## to_json writes such floats as EXACT_PREFIX + the hex of their 8 bytes, and parse_json turns
## them back into the same float (D26). Read save and command-log text with parse_json.

## Marks a float written exactly: "#f64:" + 16 hex digits (little-endian IEEE 754 bytes).
const EXACT_PREFIX: String = "#f64:"


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


## Canonical JSON text for saves and comparisons: sorted keys, full float precision, and
## floats that would not read back exactly written as EXACT_PREFIX text.
static func to_json(data: Variant, pretty: bool = true) -> String:
	return JSON.stringify(exact_floats(data), "\t" if pretty else "", true, true)


## Parses text written by to_json into `json.data`, with exact floats restored. Returns the
## parse error (OK on success), like JSON.parse.
static func parse_json(json: JSON, text: String) -> Error:
	var error := json.parse(text)
	if error == OK:
		json.data = restore_floats(json.data)
	return error


## A copy of `data` in which every float that JSON would not read back exactly is replaced
## by its EXACT_PREFIX text.
static func exact_floats(data: Variant) -> Variant:
	if data is float:
		var value: float = data
		return value if _reads_back(value) else EXACT_PREFIX + PackedFloat64Array([value]).to_byte_array().hex_encode()
	if data is Dictionary:
		var out: Dictionary = {}
		for key: Variant in (data as Dictionary):
			out[key] = exact_floats((data as Dictionary)[key])
		return out
	if data is Array:
		var out: Array = []
		for item: Variant in (data as Array):
			out.append(exact_floats(item))
		return out
	return data


## A copy of parsed JSON with every EXACT_PREFIX text turned back into its float.
static func restore_floats(data: Variant) -> Variant:
	if data is String:
		var text: String = data
		if text.length() == EXACT_PREFIX.length() + 16 and text.begins_with(EXACT_PREFIX):
			var hex := text.substr(EXACT_PREFIX.length())
			if hex.is_valid_hex_number():
				return hex.hex_decode().to_float64_array()[0]
		return data
	if data is Dictionary:
		var out: Dictionary = {}
		for key: Variant in (data as Dictionary):
			out[key] = restore_floats((data as Dictionary)[key])
		return out
	if data is Array:
		var out: Array = []
		for item: Variant in (data as Array):
			out.append(restore_floats(item))
		return out
	return data


## True if JSON writes `value` in a form that its parser reads back as the same float.
static func _reads_back(value: float) -> bool:
	if is_nan(value) or is_inf(value):
		return true  # left to JSON as before; the sim never stores these
	var json := JSON.new()
	if json.parse(JSON.stringify([value], "", false, true)) != OK:
		return false
	var back: Variant = (json.data as Array)[0]
	return back is float and (back as float) == value
