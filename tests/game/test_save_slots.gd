extends TestCase
## T-0014: save slots, the daily autosave, and Continue loading the newest save. Every test
## works in its own folder, never in the real user://saves.

const DIR: String = "user://test_saves_t0014"
const ROOM: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]

var _saves: SaveSlots
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
	_clear()
	DirAccess.make_dir_recursive_absolute(DIR)
	_saves = SaveSlots.new(DIR)


func after_each() -> void:
	Session.saves = _old_saves
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session.viewed_level = _old_level
	_clear()


func _clear() -> void:
	var folder := DirAccess.open(DIR)
	if folder == null:
		return
	for file: String in folder.get_files():
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


func _write(path: String, text: String = "{}") -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _sim_at(day: int, hour: int, minute: int) -> Sim:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	return sim


func test_paths_are_in_the_folder_in_order() -> void:
	assert_true(_saves.slot_path(2).ends_with("/slot_2.json"), _saves.slot_path(2))
	var paths := _saves.all_paths()
	assert_eq(paths.size(), 6)
	assert_eq(paths, [
		DIR + "/quicksave.json", DIR + "/slot_1.json", DIR + "/slot_2.json", DIR + "/slot_3.json",
		DIR + "/autosave_1.json", DIR + "/autosave_2.json",
	])


func test_newest_save_is_the_last_one_written() -> void:
	assert_eq(_saves.newest_save(), "", "no saves yet")
	_write(_saves.slot_path(3))
	assert_eq(_saves.newest_save(), _saves.slot_path(3))
	# Modification times have one-second resolution.
	OS.delay_msec(1100)
	_write(_saves.quicksave_path())
	assert_eq(_saves.newest_save(), _saves.quicksave_path())


func test_autosaves_rotate_between_two_files() -> void:
	assert_eq(_saves.next_autosave_path(), _saves.autosave_path(1))
	_write(_saves.autosave_path(1))
	assert_eq(_saves.next_autosave_path(), _saves.autosave_path(2))
	OS.delay_msec(1100)
	_write(_saves.autosave_path(2))
	assert_eq(_saves.next_autosave_path(), _saves.autosave_path(1), "both exist: the older one")


func test_autosave_timing_follows_the_game_day() -> void:
	var morning := SimClock.ticks_for(0, 8, 0)
	assert_eq(SaveSlots.last_autosave_day_at(morning), 0)
	assert_false(SaveSlots.autosave_due(SimClock.ticks_for(0, 23, 59), 0))
	assert_false(SaveSlots.autosave_due(SimClock.ticks_for(1, 2, 59), 0))
	assert_true(SaveSlots.autosave_due(SimClock.ticks_for(1, 3, 0), 0))
	var night := SimClock.ticks_for(1, 2, 0)
	assert_eq(SaveSlots.last_autosave_day_at(night), 0)
	assert_false(SaveSlots.autosave_due(SimClock.ticks_for(1, 2, 59), 0))
	assert_true(SaveSlots.autosave_due(SimClock.ticks_for(1, 3, 0), 0))


func test_describe_game_time_reads_the_saves_clock() -> void:
	var path := _saves.slot_path(1)
	_write(path, SaveCodec.to_json(_sim_at(2, 14, 5)))
	assert_eq(SaveSlots.describe_game_time(path), "Day 3  Wed 14:05")
	assert_eq(SaveSlots.describe_game_time(_saves.slot_path(2)), "", "missing file")
	_write(_saves.slot_path(2), "not a save")
	assert_eq(SaveSlots.describe_game_time(_saves.slot_path(2)), "", "not a save")
	assert_eq(SaveSlots.describe_real_time(path).length(), 16, SaveSlots.describe_real_time(path))


func test_session_autosaves_once_at_three_in_the_morning() -> void:
	Session.saves = _saves
	Session.content = content()
	Session.sim = _sim_at(0, 2, 59)
	Session._after_load()
	Session.speed = 1
	# One game minute at 1x: 20 steps.
	Session._process(1.0)
	assert_true(FileAccess.file_exists(_saves.autosave_path(1)), "03:00 should autosave")
	Session._process(1.0)
	assert_false(FileAccess.file_exists(_saves.autosave_path(2)), "only one autosave per day")


func test_main_menu_continue_needs_a_save() -> void:
	Session.saves = _saves
	Session.content = content()
	var menu := MainMenu.new()
	menu._ready()
	assert_true(menu._continue_button.disabled, "no saves: nothing to continue")
	assert_false(menu._continue_info.visible)
	_write(_saves.slot_path(1), SaveCodec.to_json(_sim_at(0, 9, 30)))
	menu.refresh_continue()
	assert_false(menu._continue_button.disabled)
	assert_true(menu._continue_info.text.begins_with("Day 1  Mon 09:30"), menu._continue_info.text)
	menu.free()
