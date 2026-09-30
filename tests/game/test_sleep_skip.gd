extends TestCase
## T-0013: time runs at Session.SKIP_SPEED while the player sleeps, and a critical need
## wakes them (and stops the skip for that sleep).

const ROOM: PackedStringArray = [
	"########",
	"#@.....#",
	"#......#",
	"#......#",
	"########",
]

var _old_content: ContentDB
var _old_sim: Sim
var _old_speed: int = 1
var _old_stopped: int = -1
var _old_level: int = 0


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_speed = Session.speed
	_old_stopped = Session._skip_stopped_tick
	_old_level = Session.viewed_level


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session._skip_stopped_tick = _old_stopped
	Session.skipping = false
	Session.viewed_level = _old_level


## A room with a bed and a TV; the player (no free will) on the bed's slot with all needs
## at 80, then `needs`, performing `interaction_id` after one step. Made Session's game.
func _sleeper(interaction_id: String, needs: Dictionary) -> Sim:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(3, 1, 0))
	var tv := _place(sim, "tv", Vector3i(6, 1, 0))
	var player := sim.world.player()
	player.free_will = false
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 80.0
	for need_id: String in needs:
		player.needs[need_id] = float(needs[need_id])
	var target := bed if interaction_id == "sleep" else tv
	var slot := target.slot_cell(sim.content, 0)
	player.pos = Vector2(slot.x + 0.5, slot.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, interaction_id, target.id))
	sim.step()
	Session.content = content()
	Session.sim = sim
	Session._after_load()
	Session.speed = 1
	Session._skip_stopped_tick = -1
	Session._accumulator = 0.0
	return sim


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	assert_true(sim.world.add_object(obj), "could not place %s at %s" % [def_id, cell])
	return obj


func test_should_skip_only_while_sleeping_unpaused() -> void:
	var sim := _sleeper("sleep", {})
	var action: Action = sim.world.player().action_queue[0]
	assert_eq(action.state, Action.PERFORMING)
	assert_true(Session.should_skip(sim, 1, -1), "sleeping at 1x")
	assert_false(Session.should_skip(sim, 0, -1), "paused")
	assert_false(Session.should_skip(sim, 1, action.started_tick), "stopped for this sleep")
	action.state = Action.ROUTING
	assert_false(Session.should_skip(sim, 1, -1), "still walking to the bed")
	var tv_sim := _sleeper("watch_tv", {})
	assert_false(Session.should_skip(tv_sim, 1, -1), "watching TV does not skip")


func test_sleeping_runs_many_steps_per_frame_until_the_sleep_ends() -> void:
	var sim := _sleeper("sleep", {"energy": 95.0})
	Session._process(0.05)
	assert_true(Session.skipping)
	assert_eq(Session.steps_last_frame, 120, "0.05 s at 120x is 6 game minutes")
	for i: int in 20:
		if sim.world.player().action_queue.is_empty():
			break
		Session._process(0.05)
	assert_true(sim.world.player().action_queue.is_empty(), "sleep should end (60 minutes)")
	Session._accumulator = 0.0
	Session._process(0.05)
	assert_false(Session.skipping)
	assert_eq(Session.steps_last_frame, 1, "back to 1x")


func test_a_critical_need_wakes_the_player() -> void:
	var sim := _sleeper("sleep", {"hunger": 15.05})
	var first_boundary := (sim.clock.tick / SimClock.STEPS_PER_GAME_MINUTE + 1) * SimClock.STEPS_PER_GAME_MINUTE
	var notices: Array[String] = []
	var listener := func(text: String) -> void: notices.append(text)
	Session.notice.connect(listener)
	Session._process(0.05)
	Session.notice.disconnect(listener)
	assert_false(Session.skipping, "hunger went critical: stop skipping")
	assert_eq(sim.clock.tick, first_boundary, "stop at the event, without spending the remaining skip budget")
	assert_near(sim.world.player().needs["hunger"], 14.95)
	assert_has(notices, "Woke up: Hunger is low")
	Session._accumulator = 0.0
	Session._process(0.05)
	assert_false(Session.skipping, "not again for the same sleep")
	assert_eq(Session.steps_last_frame, 1)
	assert_false(sim.world.player().action_queue.is_empty(), "the player keeps sleeping at normal speed")


func test_cancelling_sleep_discards_the_frame_skip_budget() -> void:
	var sim := _sleeper("sleep", {})
	var before := sim.clock.tick
	Session.submit(CancelActionCommand.new(sim.world.player_id, 0))
	Session._process(0.05)
	assert_eq(sim.clock.tick, before + 1)
	assert_eq(Session.steps_last_frame, 1)
	assert_false(Session.skipping)
	assert_true(sim.world.player().action_queue.is_empty())
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, 1, "accelerated remainder cannot leak into the next frame")


func test_finishing_sleep_discards_the_frame_skip_budget() -> void:
	var sim := _sleeper("sleep", {"energy": 99.0})
	sim.run_steps(SimClock.STEPS_PER_GAME_MINUTE * 60 - 2)
	assert_false(sim.world.player().action_queue.is_empty())
	var before := sim.clock.tick
	Session._process(0.05)
	assert_eq(sim.clock.tick, before + 1)
	assert_false(Session.skipping)
	assert_true(sim.world.player().action_queue.is_empty())
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, 1)


func test_replacing_sleep_with_another_sleep_discards_the_old_budget() -> void:
	var sim := _sleeper("sleep", {})
	var previous := sim.world.player().action_queue[0]
	Session.submit(QueueInteractionCommand.new(sim.world.player_id, "sleep", previous.target_id))
	Session.submit(CancelActionCommand.new(sim.world.player_id, 0, previous.id))
	var before := sim.clock.tick
	Session._process(0.05)
	assert_eq(sim.clock.tick, before + 1)
	assert_ne(sim.world.player().action_queue[0].id, previous.id)
	assert_false(Session.skipping)
	Session._process(0.05)
	assert_true(Session.skipping, "the new sleep can skip on its own next frame")
	assert_eq(Session.steps_last_frame, 120)
