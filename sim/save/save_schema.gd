class_name SaveSchema
extends RefCounted
## Safe, non-coercing readers used before any saved state is constructed.

const MAX_INTEGER: int = 9007199254740991
var errors: Array[String]


func _init(p_errors: Array[String]) -> void:
	errors = p_errors


## Records a schema problem with its full field path.
func reject(path: String, expected: String) -> void:
	errors.append("%s: %s." % [path, expected])


## Reads a dictionary without converting or raising a runtime error.
func dictionary(value: Variant, path: String) -> Dictionary:
	if value is Dictionary:
		return value
	reject(path, "must be an object")
	return {}


## Reads an array without converting or raising a runtime error.
func list(value: Variant, path: String) -> Array:
	if value is Array:
		return value
	reject(path, "must be a list")
	return []


## Reads a string, preserving compatibility with unknown content ids.
func text(value: Variant, path: String) -> String:
	if value is String:
		return value
	reject(path, "must be a string")
	return ""


## Checks booleans without accepting truthy objects or strings.
func boolean(value: Variant, path: String) -> void:
	if not value is bool:
		reject(path, "must be true or false")


## Checks finite numbers and their inclusive bounds.
func number(value: Variant, path: String, minimum: float = -MAX_INTEGER, maximum: float = MAX_INTEGER) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		reject(path, "must be a finite number")
		return 0.0
	var result := float(value)
	if result < minimum or result > maximum:
		reject(path, "number is outside the allowed range")
	return result


## JSON integers arrive as floats: accept integral numbers, never strings/fractions.
func integer(value: Variant, path: String, minimum: int = 0, maximum: int = MAX_INTEGER) -> int:
	var result := number(value, path, minimum, maximum)
	if result != floor(result):
		reject(path, "must be an integer")
	return int(clampf(result, minimum, maximum))


## Checks numeric vectors before Ser's indexed readers are called.
func vector(value: Variant, path: String, size: int, integral: bool = false) -> void:
	var entries := list(value, path)
	if entries.size() != size:
		reject(path, "must contain %d coordinates" % size)
		return
	for i: int in size:
		if integral:
			integer(entries[i], "%s[%d]" % [path, i], -2147483648, 2147483647)
		else:
			number(entries[i], "%s[%d]" % [path, i], -2147483648, 2147483647)


## Checks text lists, including nested appearance features.
func strings(value: Variant, path: String) -> void:
	for entry: Variant in list(value, path):
		text(entry, path)


## Checks canonical signed 64-bit strings before String.to_int(), which logs on overflow.
static func is_integer_string(value: String) -> bool:
	if not value.is_valid_int() or value.begins_with("+"):
		return false
	var negative := value.begins_with("-")
	var digits := value.substr(1) if negative else value
	if digits.is_empty() or (digits.length() > 1 and digits.begins_with("0")) or (negative and digits == "0"):
		return false
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	return digits.length() < limit.length() or (digits.length() == limit.length() and digits <= limit)


## Checks base64 syntax before calling Godot's decoder (which logs on bad input).
func grid_bytes(value: Variant, path: String, expected_bytes: int) -> void:
	var encoded := text(value, path)
	if encoded.length() != 4 * ((expected_bytes + 2) / 3):
		reject(path, "grid data length does not match its dimensions")
		return
	var pattern := RegEx.new()
	pattern.compile("^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$")
	if pattern.search(encoded) == null:
		reject(path, "grid data must be valid base64")
		return
	if Marshalls.base64_to_raw(encoded).size() != expected_bytes:
		reject(path, "grid data length does not match its dimensions")
