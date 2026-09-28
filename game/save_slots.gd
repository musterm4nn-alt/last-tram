class_name SaveSlots
extends RefCounted
## Where the game's saves live and how they are chosen: a quicksave (F5), three manual slots
## and two rotating autosaves (one per game day at AUTOSAVE_HOUR), all in one folder.
## Session owns one (`Session.saves`); tests use their own folder.

const SLOT_COUNT: int = 3
const AUTOSAVE_COUNT: int = 2
## Autosaves happen once per game day, at this hour.
const AUTOSAVE_HOUR: int = 3

## The folder holding every save, e.g. "user://saves".
var dir: String


func _init(p_dir: String) -> void:
	dir = p_dir


## <dir>/quicksave.json
func quicksave_path() -> String:
	return dir.path_join("quicksave.json")


## <dir>/slot_1.json .. slot_3.json (index 1..SLOT_COUNT)
func slot_path(index: int) -> String:
	return dir.path_join("slot_%d.json" % index)


## <dir>/autosave_1.json, autosave_2.json (index 1..AUTOSAVE_COUNT)
func autosave_path(index: int) -> String:
	return dir.path_join("autosave_%d.json" % index)


## Quicksave, then slots 1-3, then autosaves 1-2 (whether or not the files exist).
func all_paths() -> Array[String]:
	var out: Array[String] = [quicksave_path()]
	for index: int in range(1, SLOT_COUNT + 1):
		out.append(slot_path(index))
	for index: int in range(1, AUTOSAVE_COUNT + 1):
		out.append(autosave_path(index))
	return out


## The existing file among all_paths() written most recently (ties: the earlier one in
## all_paths()), or "" if none exist.
func newest_save() -> String:
	var best := ""
	var best_time := -1
	for path: String in all_paths():
		if not FileAccess.file_exists(path):
			continue
		var written := FileAccess.get_modified_time(path)
		if written > best_time:
			best_time = written
			best = path
	return best


## Where the next autosave goes: the first autosave path that does not exist yet, otherwise
## the one written longest ago (ties: the lower number).
func next_autosave_path() -> String:
	var oldest := ""
	var oldest_time := 0
	for index: int in range(1, AUTOSAVE_COUNT + 1):
		var path := autosave_path(index)
		if not FileAccess.file_exists(path):
			return path
		var written := FileAccess.get_modified_time(path)
		if oldest.is_empty() or written < oldest_time:
			oldest = path
			oldest_time = written
	return oldest


## "Day 3  Wed 14:05" from the save's clock (Day is clock.day() + 1, like the HUD), or ""
## if the file is missing or is not a save. Reads only the clock, never the whole Sim.
static func describe_game_time(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return ""
	var clock_data: Variant = (json.data as Dictionary).get("clock")
	if not clock_data is Dictionary or not (clock_data as Dictionary).has("tick"):
		return ""
	var clock := SimClock.new()
	clock.tick = int((clock_data as Dictionary)["tick"])
	return "Day %d  %s" % [clock.day() + 1, clock.format()]


## The local real time the file was last written, "2026-09-27 21:14", or "" if missing.
static func describe_real_time(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var bias_seconds := int(Time.get_time_zone_from_system()["bias"]) * 60
	var stamp := Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path) + bias_seconds, true)
	return stamp.substr(0, 16)


## True when a clock at `tick` is at or past AUTOSAVE_HOUR on a day after `last_autosave_day`.
static func autosave_due(tick: int, last_autosave_day: int) -> bool:
	var clock := SimClock.new()
	clock.tick = tick
	return clock.day() > last_autosave_day and clock.hour() >= AUTOSAVE_HOUR


## The day an autosave counts as already done for, for a game loaded at `tick`: today if it
## is already past AUTOSAVE_HOUR, else yesterday (so loading at 08:00 does not autosave at
## once, and loading at 02:00 autosaves at 03:00).
static func last_autosave_day_at(tick: int) -> int:
	var clock := SimClock.new()
	clock.tick = tick
	return clock.day() if clock.hour() >= AUTOSAVE_HOUR else clock.day() - 1
