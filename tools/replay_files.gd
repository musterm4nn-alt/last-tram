class_name ReplayFiles
extends RefCounted
## Reads a bug-report folder (start.json, commands.json, end.json) and replays it with
## Replay. Files are read here, in tools/, because only sim/content/ may read files in sim/.


## Reads <folder>/start.json, commands.json (a JSON array of log entries) and end.json, and
## replays them. Returns {"status": "OK" | "MISMATCH" | "ERROR", "message": String,
## "commands": int, "steps": int}; ERROR when a file is missing, not valid JSON, or the
## replay cannot run.
static func check_folder(folder: String, content: ContentDB) -> Dictionary:
	var result := {"status": "ERROR", "message": "", "commands": 0, "steps": 0}
	var start: Variant = _read(folder.path_join("start.json"), result)
	var commands: Variant = _read(folder.path_join("commands.json"), result)
	var end: Variant = _read(folder.path_join("end.json"), result)
	if not String(result["message"]).is_empty():
		return result
	if not start is Dictionary or not end is Dictionary or not commands is Array:
		result["message"] = "start.json and end.json must hold saves, commands.json a list."
		return result
	var errors: Array[String] = []
	var end_tick := Replay.end_tick_of(end)
	var sim := Replay.run(start, commands, end_tick, content, errors)
	if sim == null:
		result["message"] = "; ".join(errors)
		return result
	result["commands"] = (commands as Array).size()
	result["steps"] = end_tick - Replay.end_tick_of(start)
	var difference := Replay.compare(sim, end)
	result["status"] = "OK" if difference.is_empty() else "MISMATCH"
	result["message"] = difference
	return result


## The parsed JSON in `path`, or null (with the problem put in result["message"]).
static func _read(path: String, result: Dictionary) -> Variant:
	if not FileAccess.file_exists(path):
		result["message"] = "%s is missing." % path.get_file()
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		result["message"] = "%s is not valid JSON (line %d)." % [path.get_file(), json.get_error_line()]
		return null
	return json.data
