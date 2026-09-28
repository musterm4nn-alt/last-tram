extends TestCase
## T-0015: replaying a start save plus the logged commands reproduces the end save exactly;
## changed or broken input is reported, never crashes.

const DIR: String = "user://test_replay_t0015"


## A recorded stretch of play like the game keeps it: the start save, the applied-command
## log and the end save, over `minutes` game minutes in the furnished flat (free will on),
## with a few commands from "the player" along the way.
func _record(minutes: int) -> Dictionary:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.needs["hunger"] = 25.0
	var start := SaveCodec.to_dict(sim)
	var applied: Array[Dictionary] = []
	for minute: int in minutes:
		if minute == 5:
			sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
		elif minute == 6:
			sim.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
		elif minute == 20:
			sim.submit(WalkToCommand.new(player.id, Vector3i(52, 25, 0)))
		elif minute == 40:
			sim.submit(SetFreeWillCommand.new(player.id, false))
		elif minute == 70:
			sim.submit(SetFreeWillCommand.new(player.id, true))
		sim.run_minutes(1)
		applied.append_array(sim.take_applied_commands())
	return {"start": start, "commands": applied, "end": SaveCodec.to_dict(sim)}


## A short recording in an empty room: one step to the right at minute 5, then standing
## still. Nothing else happens there, so a changed command changes the end for good.
func _record_room() -> Dictionary:
	var sim := SimFactory.from_rows(content(), PackedStringArray([
		"##########",
		"#...@....#",
		"##########",
	]))
	var player := sim.world.player()
	var start := SaveCodec.to_dict(sim)
	var applied: Array[Dictionary] = []
	for minute: int in 10:
		if minute == 5:
			sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
		elif minute == 6:
			sim.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
		sim.run_minutes(1)
		applied.append_array(sim.take_applied_commands())
	return {"start": start, "commands": applied, "end": SaveCodec.to_dict(sim)}


func test_a_recorded_run_replays_exactly() -> void:
	var run := _record(150)
	assert_true((run["commands"] as Array).size() >= 3, "the recording should hold commands")
	assert_eq(Replay.check(run["start"], run["commands"], run["end"], content()), "")


func test_a_command_pending_in_the_start_save_is_not_applied_twice() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.needs["hunger"] = 25.0
	var fridge := 0
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "fridge":
			fridge = obj.id
	# Queueing is not idempotent: applied twice, there would be two snacks in the queue.
	# No other input follows, so nothing hides a double snack.
	sim.submit(QueueInteractionCommand.new(player.id, "grab_snack", fridge))
	var start := SaveCodec.to_dict(sim)
	var applied: Array[Dictionary] = []
	for minute: int in 30:
		sim.run_minutes(1)
		applied.append_array(sim.take_applied_commands())
	assert_eq(applied.size(), 1)
	assert_eq(int(applied[0]["tick"]), int(start["clock"]["tick"]), "the pending command is logged on the first step")
	assert_eq(Replay.check(start, applied, SaveCodec.to_dict(sim), content()), "")


func test_a_changed_command_is_found() -> void:
	var run := _record_room()
	assert_eq(Replay.check(run["start"], run["commands"], run["end"], content()), "")
	var applied: Array = run["commands"]
	var changed := (applied[0] as Dictionary).duplicate(true)
	changed["command"]["direction"] = [-1.0, 0.0]
	applied[0] = changed
	var message := Replay.check(run["start"], applied, run["end"], content())
	assert_true(message.begins_with("world.people[0]."), message)


func test_first_difference_names_the_path() -> void:
	var a := {"world": {"people": [{"pos": [12.5, 3.0]}], "tick": 5}}
	assert_eq(Replay.first_difference(a, a.duplicate(true)), "")
	var moved := a.duplicate(true)
	moved["world"]["people"][0]["pos"][0] = 12.75
	assert_eq(Replay.first_difference(a, moved), "world.people[0].pos[0]: expected 12.5, got 12.75")
	var missing := a.duplicate(true)
	(missing["world"] as Dictionary).erase("tick")
	assert_eq(Replay.first_difference(a, missing), "world.tick: expected 5, got nothing")
	var longer := a.duplicate(true)
	(longer["world"]["people"] as Array).append({"pos": [0.0, 0.0]})
	assert_eq(Replay.first_difference(a, longer), "world.people: expected 1 items, got 2")


func test_bad_input_gives_errors_not_crashes() -> void:
	var run := _record(10)
	var start: Dictionary = run["start"]
	var end_tick := Replay.end_tick_of(run["end"])
	var errors: Array[String] = []
	var unknown := [{"tick": int(start["clock"]["tick"]), "command": {"type": "teleport"}}]
	assert_eq(Replay.run(start, unknown, end_tick, content(), errors), null)
	assert_true(errors.size() == 1 and errors[0].contains("teleport"), "%s" % [errors])
	errors.clear()
	var too_early := [{"tick": int(start["clock"]["tick"]) - 1, "command": {"type": "set_move_intent", "person_id": 1, "direction": [0, 0]}}]
	assert_eq(Replay.run(start, too_early, end_tick, content(), errors), null)
	assert_true(errors.size() == 1 and errors[0].contains("outside"), "%s" % [errors])
	errors.clear()
	assert_eq(Replay.run({"not": "a save"}, [], end_tick, content(), errors), null)
	assert_false(errors.is_empty())


func _clear() -> void:
	var folder := DirAccess.open(DIR)
	if folder == null:
		return
	for file: String in folder.get_files():
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


func _write(name: String, value: Variant) -> void:
	var file := FileAccess.open(DIR.path_join(name), FileAccess.WRITE)
	file.store_string(Ser.to_json(value))
	file.close()


func test_check_folder_reads_a_report() -> void:
	_clear()
	DirAccess.make_dir_recursive_absolute(DIR)
	var run := _record(40)
	_write("start.json", run["start"])
	_write("commands.json", run["commands"])
	_write("end.json", run["end"])
	var ok := ReplayFiles.check_folder(DIR, content())
	assert_eq(ok["status"], "OK", ok["message"])
	assert_eq(ok["commands"], (run["commands"] as Array).size())
	assert_eq(ok["steps"], 40 * SimClock.STEPS_PER_GAME_MINUTE)
	var end: Dictionary = (run["end"] as Dictionary).duplicate(true)
	end["world"]["people"][0]["needs"]["fun"] = 1.0
	_write("end.json", end)
	var mismatch := ReplayFiles.check_folder(DIR, content())
	assert_eq(mismatch["status"], "MISMATCH")
	assert_true(String(mismatch["message"]).contains("needs.fun"), mismatch["message"])
	DirAccess.remove_absolute(DIR.path_join("commands.json"))
	var broken := ReplayFiles.check_folder(DIR, content())
	assert_eq(broken["status"], "ERROR")
	assert_true(String(broken["message"]).contains("commands.json"), broken["message"])
	_clear()
