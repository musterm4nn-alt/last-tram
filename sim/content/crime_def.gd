class_name CrimeDef
extends RefCounted
## A kind of crime (T-0091; data/crimes.json, docs/design/crime-and-police.md). An
## interaction with `crime` set to this id commits it when it finishes.

var id: String = ""
var name: String = ""
## How serious it is, 1 (trespassing) to 8 (killing): police priority, fines, jail time.
var severity: int = 1
