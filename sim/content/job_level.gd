class_name JobLevel
extends RefCounted
## One step of a job's career track (data/jobs.json "levels").

var title: String = ""
## Euro cents per hour worked, after tax.
var wage: int = 0
## Skill levels needed to be promoted to this level (T-0071): skill id -> level.
var requires: Dictionary[String, float] = {}
