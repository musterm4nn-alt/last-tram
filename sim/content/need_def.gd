class_name NeedDef
extends RefCounted
## One need (hunger, energy...). Defined in data/needs.json. Values are 0-100.

var id: String = ""
var name: String = ""
## How much the need drops per game hour.
var decay_per_hour: float = 0.0
## Value a new person starts with.
var start: float = 80.0
## How much low values of this need hurt mood (see Mood.compute).
var urgency_weight: float = 1.0
## Crossing below this value emits a need_critical event.
var critical_below: float = 15.0
