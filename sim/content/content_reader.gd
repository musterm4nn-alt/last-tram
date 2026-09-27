class_name ContentReader
extends RefCounted
## Typed JSON readers for content loading. Loading never crashes: problems are
## collected in `errors` instead of failing. ContentDB drains `errors` into its
## own `errors` after loading, so the public API (`db.errors`) is unchanged.
##
## `errors` is a plain Array (not PackedStringArray) because packed arrays are
## copied when passed to another object, so loader appends would not stick.

## Problems found while reading, in the order they were reported.
var errors: Array[String] = []


## Record a loading problem without crashing.
func error(message: String) -> void:
	errors.append(message)


## The parsed JSON file, or null (with an error recorded).
func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: file not found" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("%s: invalid JSON at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## The string at `key`, or "" (with an error recorded).
func read_str(d: Dictionary, key: String, ctx: String) -> String:
	var v: Variant = d.get(key)
	if not v is String:
		errors.append("%s: '%s' must be a string" % [ctx, key])
		return ""
	return v


## The number at `key`, or 0.0 (with an error recorded).
func read_num(d: Dictionary, key: String, ctx: String) -> float:
	var v: Variant = d.get(key)
	if not (v is float or v is int):
		errors.append("%s: '%s' must be a number" % [ctx, key])
		return 0.0
	return float(v)


## The boolean at `key`, or false (with an error recorded).
func read_bool(d: Dictionary, key: String, ctx: String) -> bool:
	var v: Variant = d.get(key)
	if not v is bool:
		errors.append("%s: '%s' must be true or false" % [ctx, key])
		return false
	return v


## The list at `key`, or [] (with an error recorded).
func read_arr(d: Dictionary, key: String, ctx: String) -> Array:
	var v: Variant = d.get(key)
	if not v is Array:
		errors.append("%s: '%s' must be a list" % [ctx, key])
		return []
	return v


## The object at `key`, or {} (with an error recorded).
func read_obj(d: Dictionary, key: String, ctx: String) -> Dictionary:
	var v: Variant = d.get(key)
	if not v is Dictionary:
		errors.append("%s: '%s' must be an object" % [ctx, key])
		return {}
	return v


## The list of strings at `key` (with an error recorded per bad entry).
func read_str_array(d: Dictionary, key: String, ctx: String) -> PackedStringArray:
	var v: Variant = d.get(key)
	if not v is Array:
		errors.append("%s: '%s' must be a list of strings" % [ctx, key])
		return PackedStringArray()
	var out := PackedStringArray()
	for entry: Variant in v:
		if not entry is String:
			errors.append("%s: every entry of '%s' must be a string" % [ctx, key])
			continue
		out.append(String(entry))
	return out
