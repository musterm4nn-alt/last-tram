extends TestCase
## T-0024: F9 bug reports. The folder holds the start save, the commands since, the save
## now and an info file, and replays exactly, also after an autosave moved the start.

const DIR: String = "user://test_bug_reports_t0024"
const SAVES_DIR: String = "user://test_saves_t0024"

var _old_saves: SaveSlots
var _old_content: ContentDB
var _old_sim: Sim
var _old_speed: int = 1
var _old_level: int = 0


func before_each() -> void:
	_old_saves = Session.saves
	_old_content = Session.content
	_old_sim = Session.sim
	_old_speed = Session.speed
	_old_level = Session.viewed_level
	_remove_tree(DIR)
	_remove_tree(SAVES_DIR)
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	Session.saves = SaveSlots.new(SAVES_DIR)
	Session.content = content()
	Session.speed = 1


func after_each() -> void:
	Session.saves = _old_saves
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session.viewed_level = _old_level
	_remove_tree(DIR)
	_remove_tree(SAVES_DIR)


## Deletes a folder, its files and its sub-folders (one level deep, like report folders).
func _remove_tree(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		return
	for sub: String in folder.get_directories():
		_remove_tree(path.path_join(sub))
	for file: String in folder.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _start_game(day: int, hour: int, minute: int) -> Sim:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	Session.sim = sim
	Session._after_load()
	Session._accumulator = 0.0
	return sim


func _read_json(path: String) -> Variant:
	var json := JSON.new()
	assert_eq(json.parse(FileAccess.get_file_as_string(path)), OK, "%s should be JSON" % path)
	return json.data


func test_a_report_holds_everything_and_replays_exactly() -> void:
	var sim := _start_game(0, 8, 0)
	var player := sim.world.player()
	Session._process(0.25)
	Session.submit(WalkToCommand.new(player.id, Vector3i(52, 25, 0)))
	Session._process(0.25)
	Session._process(0.25)
	Session.submit(SetMoveIntentCommand.new(player.id, Vector2.LEFT))
	Session._process(0.25)
	Session.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
	for i: int in 8:
		Session._process(0.25)
	var folder := Session.write_bug_report(null, DIR)
	assert_false(folder.is_empty(), "the report should be written")
	for file: String in ["start.json", "commands.json", "end.json", "info.txt"]:
		assert_true(FileAccess.file_exists(folder.path_join(file)), "%s is missing" % file)
	assert_false(FileAccess.file_exists(folder.path_join("screenshot.png")), "no screenshot was given")
	var commands: Array = _read_json(folder.path_join("commands.json"))
	assert_eq(commands.size(), 3)
	assert_eq(Replay.check(_read_json(folder.path_join("start.json")), commands, _read_json(folder.path_join("end.json")), content()), "")
	assert_eq(ReplayFiles.check_folder(folder, content())["status"], "OK", "the replay tool reads what the game writes")


func test_after_an_autosave_the_report_starts_there() -> void:
	var sim := _start_game(0, 2, 58)
	var player := sim.world.player()
	Session.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	Session._process(1.0)
	Session._process(1.0)
	assert_true(FileAccess.file_exists(Session.saves.autosave_path(1)), "03:00 should have autosaved")
	var autosaved_at := SimClock.ticks_for(0, 3, 0)
	Session.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
	Session._process(0.25)
	var folder := Session.write_bug_report(null, DIR)
	var start: Dictionary = _read_json(folder.path_join("start.json"))
	assert_eq(int(start["clock"]["tick"]), autosaved_at, "the report starts at the autosave")
	var commands: Array = _read_json(folder.path_join("commands.json"))
	assert_eq(commands.size(), 1, "only the command after the autosave")
	assert_eq(Replay.check(start, commands, _read_json(folder.path_join("end.json")), content()), "")


func test_two_reports_in_the_same_second_get_their_own_folders() -> void:
	_start_game(0, 8, 0)
	var first := Session.write_bug_report(null, DIR)
	var second := Session.write_bug_report(null, DIR)
	assert_false(first.is_empty())
	assert_false(second.is_empty())
	assert_ne(first, second)


func test_info_says_when_and_who() -> void:
	var sim := _start_game(1, 14, 5)
	var folder := Session.write_bug_report(null, DIR)
	var info := FileAccess.get_file_as_string(folder.path_join("info.txt"))
	assert_true(info.contains("Day 2  Tue 14:05"), info)
	assert_true(info.contains(sim.world.player().full_name()), info)
