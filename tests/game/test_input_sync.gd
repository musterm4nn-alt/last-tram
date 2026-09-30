extends TestCase
## Review regression: loaded movement is replaced by the current input through a command.

const ROOM: PackedStringArray = ["##########", "#........#", "#...@....#", "#........#", "##########"]
var _old_sim: Sim
var _old_content: ContentDB
var _old_mode: bool


func before_each() -> void:
	_old_sim = Session.sim
	_old_content = Session.content
	_old_mode = Session.command_mode
	Session.content = content()
	Session.command_mode = false
	InputActions.register()


func after_each() -> void:
	Session.sim = _old_sim
	Session.content = _old_content
	Session.command_mode = _old_mode


func test_released_keys_stop_every_loaded_direction_before_movement() -> void:
	for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var original := SimFactory.from_rows(content(), ROOM)
		original.submit(SetMoveIntentCommand.new(original.world.player_id, direction))
		original.step()
		Session.sim = SaveCodec.from_json(SaveCodec.to_json(original), content())
		var controller := PlayerController.new()
		controller.reset()
		var player := Session.sim.world.player()
		var before := player.pos
		controller._process(0.0)
		assert_eq(Session.sim.pending_commands().size(), 1)
		assert_eq(player.move_intent, direction, "input changes sim only through a command")
		Session.sim.run_steps(10)
		assert_eq(player.move_intent, Vector2.ZERO)
		assert_eq(player.pos, before)
		controller._process(0.0)
		assert_true(Session.sim.pending_commands().is_empty(), "no repeated stop commands")
		controller.free()


func test_reset_resends_held_input_after_another_game_is_loaded() -> void:
	Session.sim = SimFactory.from_rows(content(), ROOM)
	var controller := PlayerController.new()
	controller.forced_direction = Vector2.RIGHT
	controller._process(0.0)
	Session.sim.step()
	Session.sim = SimFactory.from_rows(content(), ROOM)
	controller.reset()
	controller._process(0.0)
	Session.sim.step()
	assert_eq(Session.sim.world.player().move_intent, Vector2.RIGHT)
	controller.free()


func test_input_sync_preserves_a_loaded_click_to_walk_path() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.submit(WalkToCommand.new(sim.world.player_id, Vector3i(8, 3, 0)))
	sim.step()
	Session.sim = SaveCodec.from_json(SaveCodec.to_json(sim), content())
	Session.command_mode = true
	var controller := PlayerController.new()
	controller.reset()
	controller._process(0.0)
	Session.sim.step()
	assert_false(Session.sim.world.player().path.is_empty())
	controller.free()


func test_game_loaded_synchronizes_input_before_session_steps_its_first_frame() -> void:
	var original := SimFactory.from_rows(content(), ROOM)
	original.submit(SetMoveIntentCommand.new(original.world.player_id, Vector2.RIGHT))
	original.step()
	Session.sim = SaveCodec.from_json(SaveCodec.to_json(original), content())
	var controller := PlayerController.new()
	Session.game_loaded.connect(controller.reset)
	var before := Session.sim.world.player().pos
	Session.game_loaded.emit()
	assert_eq(Session.sim.pending_commands().size(), 1)
	Session.sim.step()
	assert_eq(Session.sim.world.player().pos, before)
	Session.game_loaded.disconnect(controller.reset)
	controller.free()
