class_name MoodletDef
extends RefCounted
## A kind of temporary mood modifier (data/moodlets.json): "Slept well +10 for 6 hours".

var id: String = ""
var name: String = ""
## Added to mood while it lasts (−100..100).
var value: int = 0
## How long it lasts, in game hours.
var duration_hours: float = 1.0
