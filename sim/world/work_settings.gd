class_name WorkSettings
extends RefCounted
## How work treats people (T-0077, saved with the world): with `gentle` off (the default),
## each job has its own need profile (data/jobs.json); with it on, every job uses the shared
## gentle profile (data/economy.json "gentle_profile"). "Work: varied / gentle" in the Esc menu.

var gentle: bool = false


func to_dict() -> Dictionary:
	return {"gentle": gentle}


static func from_dict(d: Dictionary) -> WorkSettings:
	var w := WorkSettings.new()
	w.gentle = bool(d.get("gentle", false))
	return w
