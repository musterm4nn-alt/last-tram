class_name Personality
extends RefCounted
## Seven personality axes, each −100..+100 (docs/design/people.md → "Personality"):
## kindness (cruel ↔ caring), honesty, sociability, ambition, temper (calm ↔ hot-headed),
## vice (restrained ↔ indulgent) and bravery. Neutral (0) unless set or drawn at random.

const AXES: PackedStringArray = ["kindness", "honesty", "sociability", "ambition", "temper", "vice", "bravery"]
const MIN_VALUE: int = -100
const MAX_VALUE: int = 100

## Every axis in AXES -> its value, always within MIN_VALUE..MAX_VALUE.
var values: Dictionary[String, int] = {}


func _init() -> void:
	for axis: String in AXES:
		values[axis] = 0


## The value of `axis` (0 for an unknown axis).
func get_axis(axis: String) -> int:
	return values.get(axis, 0)


## Sets a known axis, clamped to MIN_VALUE..MAX_VALUE. Unknown axes are ignored.
func set_axis(axis: String, value: int) -> void:
	if AXES.has(axis):
		values[axis] = clampi(value, MIN_VALUE, MAX_VALUE)


func copy() -> Personality:
	var out := Personality.new()
	for axis: String in AXES:
		out.values[axis] = values[axis]
	return out


func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for axis: String in AXES:
		out[axis] = values[axis]
	return out


## Missing or unknown axes read as 0; values are clamped.
static func from_dict(d: Dictionary) -> Personality:
	var out := Personality.new()
	for axis: String in AXES:
		out.set_axis(axis, int(d.get(axis, 0)))
	return out


## Each axis is the sum of two draws in −50..50, so most people are moderate. Draws the axes
## in AXES order.
static func random(rng: RandomNumberGenerator) -> Personality:
	var out := Personality.new()
	for axis: String in AXES:
		out.set_axis(axis, rng.randi_range(-50, 50) + rng.randi_range(-50, 50))
	return out
