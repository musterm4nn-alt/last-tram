extends TestCase
## T-0049: Page Up/Down climbs stairs (direct mode) or pages floors (command mode); the view
## follows the player's floor; clicks act on the viewed floor.

const GROUND: PackedStringArray = ["######", "#@..^#", "######"]
const FLOOR: PackedStringArray = ["######", "#...^#", "######"]

var _old_content: ContentDB
var _old_sim: Sim
var _old_mode: bool = false
var _old_level: int = 0
var _notices: Array[String] = []


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_mode = Session.command_mode
	_old_level = Session.viewed_level
	Session.content = content()
	Session.command_mode = false
	_notices.clear()
	Session.notice.connect(_on_notice)


func after_each() -> void:
	Session.notice.disconnect(_on_notice)
	Session.content = _old_content
	Session.sim = _old_sim
	Session.command_mode = _old_mode
	Session.viewed_level = _old_level


func _on_notice(text: String) -> void:
	_notices.append(text)


## Levels 0 and 1 joined by stairs at (4, 1); `extra` adds more levels (level -> rows).
func _house(extra: Dictionary = {}) -> Sim:
	var sim := SimFactory.from_rows(content(), GROUND)
	sim.world.grid.stamp_rows(1, Vector2i.ZERO, FLOOR)
	for level: int in extra:
		sim.world.grid.stamp_rows(level, Vector2i.ZERO, extra[level])
	Session.sim = sim
	Session.viewed_level = 0
	Session._followed_level = 0
	return sim


func test_page_level_walks_through_existing_levels_and_stops_at_the_ends() -> void:
	_house({3: FLOOR, -1: FLOOR})
	Session.page_level(1)
	assert_eq(Session.viewed_level, 1)
	Session.page_level(1)
	assert_eq(Session.viewed_level, 3, "skips the missing level 2")
	Session.page_level(1)
	assert_eq(Session.viewed_level, 3, "stops at the top")
	Session.page_level(-1)
	Session.page_level(-1)
	assert_eq(Session.viewed_level, 0)
	Session.page_level(-1)
	assert_eq(Session.viewed_level, -1)
	Session.page_level(-1)
	assert_eq(Session.viewed_level, -1, "stops at the bottom")
	Session.view_level(7)
	assert_eq(Session.viewed_level, -1, "view_level ignores a missing level")
	Session.view_level(1)
	assert_eq(Session.viewed_level, 1)


func test_a_paged_view_stays_until_the_player_changes_floor() -> void:
	var sim := _house()
	Session.set_command_mode(true)
	Session.page_level(1)
	Session._follow_player_level()
	assert_eq(Session.viewed_level, 1, "stays while the player stays on floor 0")
	Session.page_level(-1)
	sim.world.player().level = 1  # as if the player just climbed
	Session._follow_player_level()
	assert_eq(Session.viewed_level, 1, "follows the player's new floor")
	Session.page_level(-1)
	assert_eq(Session.viewed_level, 0)
	Session.set_command_mode(false)
	assert_eq(Session.viewed_level, 1, "direct mode snaps to the player's floor")


func test_page_up_on_the_stairs_climbs_and_page_down_comes_back() -> void:
	var sim := _house()
	var player := sim.world.player()
	player.pos = Vector2(4.5, 1.5)
	var controller := PlayerController.new()
	controller.press_level_key(1)
	assert_eq(sim.pending_commands().size(), 1)
	assert_eq((sim.pending_commands()[0] as WalkToCommand).target, Vector3i(4, 1, 1))
	sim.run_steps(20)
	assert_eq(player.level, 1)
	controller.press_level_key(1)
	assert_true(sim.pending_commands().is_empty(), "no stairs further up")
	assert_eq(_notices, ["No stairs here"] as Array[String])
	controller.press_level_key(-1)
	sim.run_steps(20)
	assert_eq(player.level, 0)
	controller.free()


func test_page_up_off_the_stairs_says_no_stairs_here() -> void:
	var sim := _house()
	var controller := PlayerController.new()
	controller.press_level_key(1)
	assert_true(sim.pending_commands().is_empty())
	assert_eq(_notices, ["No stairs here"] as Array[String])
	controller.free()


func test_command_mode_page_keys_page_the_view_not_the_player() -> void:
	var sim := _house()
	Session.set_command_mode(true)
	var controller := PlayerController.new()
	controller.press_level_key(1)
	assert_eq(Session.viewed_level, 1)
	assert_true(sim.pending_commands().is_empty())
	controller.free()


func test_a_click_while_viewing_floor_one_walks_to_floor_one() -> void:
	var sim := _house()
	var player := sim.world.player()
	Session.view_level(1)
	var command := PlayerController.walk_command(player, Vector2(2.5, 1.5) * ViewConfig.TILE_PX, Session.viewed_level)
	assert_eq(command.target, Vector3i(2, 1, 1))
	sim.submit(command)
	sim.run_minutes(2)
	assert_eq(player.cell(), Vector3i(2, 1, 1), "walked up the stairs to the clicked cell")


func test_mode_label_names_another_floor() -> void:
	var player := Person.new()
	player.level = 0
	assert_eq(Hud.mode_text(0, player), "Command mode")
	assert_eq(Hud.mode_text(2, player), "Command mode · floor 2")


func test_level_launch_option_parses() -> void:
	assert_eq(LaunchOptions.parse(PackedStringArray(["--level=2"])).level, 2)
	assert_eq(LaunchOptions.parse(PackedStringArray([])).level, LaunchOptions.NO_LEVEL)
