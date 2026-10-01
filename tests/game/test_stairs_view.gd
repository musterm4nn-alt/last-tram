extends TestCase
## T-0030: the view shows whichever floor the player is on after they take the stairs.

const DIR: String = "user://test_saves_t0030"

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
	Session.saves = SaveSlots.new(DIR)
	Session.content = content()


func after_each() -> void:
	Session.saves = _old_saves
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session.viewed_level = _old_level


func test_the_view_follows_the_player_up_the_stairs() -> void:
	var sim := SimFactory.from_rows(content(), [
		"######",
		"#@..^#",
		"######",
	])
	sim.world.grid.stamp_rows(1, Vector2i.ZERO, [
		"######",
		"#...^#",
		"######",
	])
	sim.submit(WalkToCommand.new(sim.world.player_id, Vector3i(1, 1, 1)))
	sim.run_steps(SimClock.STEPS_PER_GAME_MINUTE)
	assert_eq(sim.world.player().level, 1, "walked up")
	Session.sim = sim
	Session.viewed_level = 0
	Session.speed = 1
	Session._process(0.1)
	assert_eq(Session.viewed_level, 1)
