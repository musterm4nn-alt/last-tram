class_name WitnessRules
extends RefCounted
## How people notice crimes (T-0092; "witness" in data/crimes.json).

## Sight range in cells by day and at night (night_from:00 to night_until:00).
var day_range: int = 8
var night_range: int = 5
var night_from: int = 21
var night_until: int = 6
## The "saw_crime" memory a witness gets.
var memory_valence: int = -40
var memory_salience: float = 70.0
