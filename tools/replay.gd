extends SceneTree
## Replays a bug-report folder headless and says whether it reproduces the end save:
##   tools/replay.sh <folder>
## The folder holds start.json, commands.json and end.json (written by F9, T-0024).


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("REPLAY ERROR: give the bug report folder, e.g. tools/replay.sh ~/Downloads/2026-09-27_21-14-05")
		print("LAST_TRAM_REPLAY: ERROR")
		quit(2)
		return
	var content := ContentDB.load_default()
	var result := ReplayFiles.check_folder(args[0], content)
	match String(result["status"]):
		"OK":
			var count := int(result["commands"])
			print("REPLAY OK: %d command%s over %d steps reproduce the end save." % [count, "" if count == 1 else "s", result["steps"]])
			print("LAST_TRAM_REPLAY: OK")
			quit(0)
		"MISMATCH":
			print("REPLAY MISMATCH: %s" % result["message"])
			print("LAST_TRAM_REPLAY: MISMATCH")
			quit(1)
		_:
			print("REPLAY ERROR: %s" % result["message"])
			print("LAST_TRAM_REPLAY: ERROR")
			quit(2)
