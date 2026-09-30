extends TestCase
## Review regressions: failed saves preserve the last good file and replay checkpoint.

const DIR: String = "user://test_review_save_failures"
const ROOM: PackedStringArray = ["########", "#@.....#", "#......#", "########"]

class ShortWrite extends SaveFile:
	func _store(file: FileAccess, bytes: PackedByteArray) -> void:
		file.store_buffer(bytes.slice(0, 16))

var _old_sim: Sim
var _old_content: ContentDB
var _old_saves: SaveSlots
var _old_speed: int
var _old_replay: String
var _old_log: Array[Dictionary]
var _old_day: int
var _old_retry: float
var _old_level: int


func before_each() -> void:
	_old_sim = Session.sim
	_old_content = Session.content
	_old_saves = Session.saves
	_old_speed = Session.speed
	_old_replay = Session._replay_start
	_old_log = Session.command_log.duplicate(true)
	_old_day = Session._last_autosave_day
	_old_retry = Session._autosave_retry_left
	_old_level = Session.viewed_level
	DirAccess.make_dir_recursive_absolute(DIR)
	Session.content = content()
	Session.sim = SimFactory.from_rows(content(), ROOM)
	Session.sim.world.player().free_will = false
	Session.saves = SaveSlots.new(DIR)
	Session._after_load()
	Session.speed = 1


func after_each() -> void:
	Session.sim = _old_sim
	Session.content = _old_content
	Session.saves = _old_saves
	Session.speed = _old_speed
	Session._replay_start = _old_replay
	Session.command_log = _old_log
	Session._last_autosave_day = _old_day
	Session._autosave_retry_left = _old_retry
	Session.viewed_level = _old_level
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR.path_join("save.json.tmp"))
	DirAccess.remove_absolute(DIR)


func test_a_short_write_keeps_the_previous_save_byte_for_byte() -> void:
	var path := DIR.path_join("save.json")
	assert_eq(Session.save_to(path), OK)
	var previous := FileAccess.get_file_as_bytes(path)
	Session.sim.run_minutes(5)
	assert_ne(ShortWrite.new().write(path, SaveCodec.to_json(Session.sim)), OK)
	assert_eq(FileAccess.get_file_as_bytes(path), previous)
	assert_false(FileAccess.file_exists(path + ".tmp"), "failed temporary write cleaned up")
	var errors: Array[String] = []
	assert_true(SaveCodec.from_json(FileAccess.get_file_as_string(path), content(), errors) != null)
	assert_true(errors.is_empty())


func test_a_successful_write_replaces_the_save_and_preserves_unicode() -> void:
	var path := DIR.path_join("save.json")
	assert_eq(Session.save_to(path), OK)
	Session.sim.world.player().nickname = "Renée"
	Session.sim.run_steps(17)
	assert_eq(Session.save_to(path), OK)
	assert_eq(FileAccess.get_file_as_string(path), SaveCodec.to_json(Session.sim))
	assert_false(FileAccess.file_exists(path + ".tmp"))


func test_a_failed_temp_open_keeps_the_previous_save() -> void:
	var path := DIR.path_join("save.json")
	assert_eq(Session.save_to(path), OK)
	var previous := FileAccess.get_file_as_bytes(path)
	DirAccess.make_dir_recursive_absolute(path + ".tmp")
	assert_ne(Session.save_to(path), OK)
	assert_eq(FileAccess.get_file_as_bytes(path), previous)


func test_a_failed_rename_reports_failure_and_cleans_up() -> void:
	var path := DIR.path_join("save_destination")
	DirAccess.make_dir_recursive_absolute(path)
	assert_ne(Session.save_to(path), OK)
	assert_true(DirAccess.dir_exists_absolute(path))
	assert_false(FileAccess.file_exists(path + ".tmp"))
	DirAccess.remove_absolute(path)


func test_a_corrupt_load_preserves_the_running_game_and_reports_failure() -> void:
	var before := Session.sim
	var data := SaveCodec.to_dict(before)
	(data["world"] as Dictionary).erase("grid")
	var path := DIR.path_join("corrupt.json")
	assert_eq(SaveFile.new().write(path, Ser.to_json(data)), OK)
	var notices: Array[String] = []
	var listener := func(message: String) -> void: notices.append(message)
	Session.notice.connect(listener)
	assert_false(Session.load_from(path))
	Session.notice.disconnect(listener)
	assert_eq(Session.sim, before)
	assert_true(notices.size() == 1 and notices[0].begins_with("Load failed:"))
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, 1, "the preserved game remains playable")


func test_failed_autosaves_keep_the_checkpoint_and_retry_after_recovery() -> void:
	var blocked := DIR.path_join("blocked")
	var file := FileAccess.open(blocked, FileAccess.WRITE)
	file.store_string("a file blocks the save directory")
	file.close()
	Session.saves = SaveSlots.new(blocked)
	Session.sim.clock.tick = SimClock.ticks_for(1, 3)
	Session._after_load()
	Session._last_autosave_day = 0
	var checkpoint := Session._replay_start
	Session.submit(SetMoveIntentCommand.new(Session.sim.world.player_id, Vector2.RIGHT))
	Session._process(0.05)
	var commands := Session.command_log.duplicate(true)
	assert_eq(commands.size(), 1)
	assert_eq(Session._last_autosave_day, 0)
	assert_true(SaveSlots.autosave_due(Session.sim.clock.tick, Session._last_autosave_day))
	assert_eq(Session._replay_start, checkpoint)
	assert_eq(Replay.check(JSON.parse_string(checkpoint), commands, SaveCodec.to_dict(Session.sim), content()), "")
	assert_true(Session._autosave_retry_left > 0.0)
	var notices: Array[String] = []
	var listener := func(message: String) -> void: notices.append(message)
	Session.notice.connect(listener)
	Session._process(0.05)
	assert_true(notices.is_empty(), "no repeated failure notices during cooldown")
	assert_eq(Session.command_log, commands)
	assert_eq(Session._replay_start, checkpoint)
	DirAccess.remove_absolute(blocked)
	Session._process(Session.AUTOSAVE_RETRY_SECONDS)
	Session.notice.disconnect(listener)
	assert_has(notices, "Autosaved")
	assert_eq(Session._last_autosave_day, 1)
	assert_true(FileAccess.file_exists(Session.saves.autosave_path(1)))
	assert_eq(Session._replay_start, SaveCodec.to_json(Session.sim))
	assert_true(Session.command_log.is_empty())
	DirAccess.remove_absolute(Session.saves.autosave_path(1))
	DirAccess.remove_absolute(blocked)
