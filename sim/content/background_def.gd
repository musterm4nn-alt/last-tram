class_name BackgroundDef
extends RefCounted
## Where the player's life starts (T-0075; data/backgrounds.json): money, a job, skills, people
## they know, a feeling, and a record.

var id: String = ""
var name: String = ""
var description: String = ""
## Starting money in euro cents.
var cash: int = 0
var bank: int = 0
## A job id to start in, or "" for none.
var job_id: String = ""
## Skill id -> starting level.
var skills: Dictionary[String, float] = {}
## How many neighbours already know the player.
var knows: int = 0
## An optional moodlet at the start.
var moodlet_id: String = ""
## A criminal record (kept for M4).
var record: bool = false
