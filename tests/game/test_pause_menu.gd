extends TestCase
## T-0023: the Esc menu (pause, save to a slot, load) and the save lists. Every test works in
## its own save folder, never in the real user://saves.

const DIR: String = "user://test_saves_t0023"
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
	Session.saves = _saves
	Session.content = content()


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


func _sim_at(day: int, hour: int, minute: int) -> Sim:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.clock.tick = SimClock.ticks_for(day, hour, minute)
	return sim


func _write_save(path: String, sim: Sim) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SaveCodec.to_json(sim))
	file.close()


## The list's button whose text starts with `prefix`.
func _row(list: SaveList, prefix: String) -> Button:
	for child: Node in list.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child
	fail("no row starting with '%s'" % prefix)
	return null


func test_save_rows_always_show_three_slots() -> void:
	var rows := SaveList.rows(_saves, true)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["label"], "Slot 1 · empty")
	_write_save(_saves.slot_path(2), _sim_at(1, 10, 15))
	rows = SaveList.rows(_saves, true)
	assert_true(String(rows[1]["label"]).begins_with("Slot 2 · Day 2  Tue 10:15 · "), rows[1]["label"])
	assert_eq(rows[1]["path"], _saves.slot_path(2))


func test_load_rows_list_only_existing_saves_in_order() -> void:
	assert_true(SaveList.rows(_saves, false).is_empty())
	_write_save(_saves.autosave_path(1), _sim_at(0, 3, 0))
	_write_save(_saves.quicksave_path(), _sim_at(0, 9, 0))
	_write_save(_saves.slot_path(3), _sim_at(0, 12, 0))
	var labels: Array[String] = []
	for row: Dictionary in SaveList.rows(_saves, false):
		labels.append(String(row["label"]).get_slice(" · ", 0))
	assert_eq(labels, ["Quicksave", "Slot 3", "Autosave 1"])


func test_an_empty_load_list_says_so() -> void:
	var list := SaveList.new()
	list.show_rows(_saves, false)
	var none := _row(list, "No saves yet")
	assert_true(none != null and none.disabled)
	list.free()


func test_open_pauses_and_close_restores_the_speed() -> void:
	Session.sim = _sim_at(0, 8, 0)
	Session.speed = 2
	var menu := PauseMenu.new()
	menu.open()
	assert_true(menu.is_open)
	assert_true(menu.visible)
	assert_eq(Session.speed, 0)
	menu.close()
	assert_false(menu.is_open)
	assert_eq(Session.speed, 2)
	menu.free()


func test_saving_into_slot_two_writes_it() -> void:
	Session.sim = _sim_at(2, 18, 30)
	var menu := PauseMenu.new()
	menu.open()
	menu._show_list("save")
	_row(menu._list, "Slot 2").pressed.emit()
	assert_true(FileAccess.file_exists(_saves.slot_path(2)))
	assert_true(_row(menu._list, "Slot 2").text.contains("Day 3  Wed 18:30"), "the row shows the new save")
	menu.close()
	menu.free()


func test_loading_a_save_replaces_the_game_and_closes_the_menu() -> void:
	var saved := _sim_at(1, 7, 45)
	_write_save(_saves.slot_path(1), saved)
	Session.sim = _sim_at(0, 8, 0)
	Session.speed = 1
	var menu := PauseMenu.new()
	menu.open()
	menu._show_list("load")
	_row(menu._list, "Slot 1").pressed.emit()
	assert_false(menu.is_open, "loading closes the menu")
	assert_eq(Session.sim.clock.tick, saved.clock.tick)
	assert_eq(Session.speed, 1)
	menu.free()


func test_the_free_will_button_shows_and_switches_the_setting() -> void:
	var sim := _sim_at(0, 8, 0)
	Session.sim = sim
	var menu := PauseMenu.new()
	menu.open()
	assert_eq(menu._free_will_button.text, "Free will: On", "a new player has free will")
	menu._free_will_button.pressed.emit()
	assert_eq(menu._free_will_button.text, "Free will: Off")
	var pending := sim.pending_commands()
	assert_eq(pending.size(), 1)
	if pending.size() == 1:
		var command := pending[0] as SetFreeWillCommand
		assert_true(command != null, "expected a SetFreeWillCommand")
		if command != null:
			assert_eq(command.person_id, sim.world.player_id)
			assert_false(command.enabled)
	menu.close()
	menu.free()



func test_the_work_button_switches_between_varied_and_gentle_jobs() -> void:
	var sim := _sim_at(0, 8, 0)
	Session.sim = sim
	var menu := PauseMenu.new()
	menu.open()
	assert_eq(menu._work_button.text, "Work: Varied", "jobs are varied by default (T-0077)")
	menu._work_button.pressed.emit()
	assert_eq(menu._work_button.text, "Work: Gentle")
	var pending := sim.pending_commands()
	assert_eq(pending.size(), 1)
	var command := pending[0] as SetGentleWorkCommand if pending.size() == 1 else null
	assert_true(command != null and command.gentle, "expected SetGentleWorkCommand(true)")
	sim.step()
	assert_true(sim.world.work.gentle)
	menu.close()
	menu.open()
	assert_eq(menu._work_button.text, "Work: Gentle", "the menu shows the saved setting")
	menu.close()
	menu.free()
