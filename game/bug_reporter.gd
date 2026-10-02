class_name BugReporter
extends RefCounted
## F9 bug reports (T-0015, split out of Session in T-0078; static, no state): a folder with
## the save this stretch of play started from, every command since, the game now, a
## screenshot and a few lines of context. `tools/replay.sh <folder>` replays it.

## How many recent events info.txt lists.
const REPORT_EVENTS: int = 20


## Writes <base_dir>/<YYYY-MM-DD_HH-MM-SS>/ with start.json (`start_json`), commands.json
## (`command_log`), end.json (the game now), screenshot.png (unless `screenshot` is null) and
## info.txt. Returns the folder's absolute path, or "" if writing failed.
static func write(sim: Sim, start_json: String, command_log: Array[Dictionary], speed: int, screenshot: Image, base_dir: String) -> String:
	if sim == null:
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "-")
	var folder := base_dir.path_join(stamp)
	var suffix := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = base_dir.path_join("%s_%d" % [stamp, suffix])
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var ok := _write_text(folder.path_join("start.json"), start_json)
	ok = _write_text(folder.path_join("commands.json"), Ser.to_json(command_log)) and ok
	ok = _write_text(folder.path_join("end.json"), SaveCodec.to_json(sim)) and ok
	ok = _write_text(folder.path_join("info.txt"), info(sim, command_log.size(), speed)) and ok
	if screenshot != null:
		ok = screenshot.save_png(folder.path_join("screenshot.png")) == OK and ok
	return ProjectSettings.globalize_path(folder) if ok else ""


## Plain words for info.txt: when, where, who, and what happened last.
static func info(sim: Sim, commands: int, speed: int) -> String:
	var lines := PackedStringArray()
	lines.append("Last Tram bug report")
	lines.append("Real time: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Game time: Day %d  %s" % [sim.clock.day() + 1, sim.clock.format()])
	var player := sim.world.player()
	if player != null:
		lines.append("Player: %s at %s" % [player.full_name(), player.cell()])
	lines.append("Speed: %s" % ("paused" if speed == 0 else "%dx" % speed))
	lines.append("Commands since the start save: %d" % commands)
	lines.append("Recent events:")
	var recent := sim.events.recent
	for i: int in range(maxi(0, recent.size() - REPORT_EVENTS), recent.size()):
		lines.append("  %d %s %s" % [recent[i]["tick"], recent[i]["type"], recent[i]["data"]])
	return "\n".join(lines) + "\n"


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
