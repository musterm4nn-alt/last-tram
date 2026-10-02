extends TestCase
## T-0013 / T-0050 / T-0078: a sleep is skipped to its end, at most TimeSkip.STEPS_PER_FRAME
## steps per frame; a critical need wakes them (and stops the skip for that sleep), and so
## does Esc (stop_skipping).

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
	_old_stopped = Session.time_skip.stopped_tick
	_old_level = Session.viewed_level


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session.time_skip.stopped_tick = _old_stopped
	Session.time_skip.active = false
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
	Session.time_skip.stopped_tick = -1
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


func test_a_skip_runs_over_frames_to_the_end_of_the_sleep() -> void:
	var sim := _sleeper("sleep", {"energy": 40.0})
	var started := sim.world.player().action_queue[0].started_tick
	var notices: Array[String] = []
	var listener := func(text: String) -> void: notices.append(text)
	Session.notice.connect(listener)
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, TimeSkip.STEPS_PER_FRAME, "one game hour per frame")
	assert_true(Session.skipping, "still skipping")
	assert_false(sim.world.player().action_queue.is_empty())
	var frames := 1
	while not sim.world.player().action_queue.is_empty() and frames < 30:
		Session._process(0.05)
		frames += 1
	Session.notice.disconnect(listener)
	assert_true(sim.world.player().action_queue.is_empty(), "the sleep ended")
	assert_true(frames > 2 and frames < 30, "over a few frames (%d)" % frames)
	assert_true(sim.clock.tick >= started + SimClock.STEPS_PER_GAME_MINUTE * 60, "slept at least its 60 minutes")
	assert_false(Session.skipping)
	assert_eq(notices, ["Woke up at %s" % sim.clock.format()] as Array[String])
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, 1, "back to 1x")


func test_esc_stops_a_skip() -> void:
	var sim := _sleeper("sleep", {"energy": 40.0})
	Session._process(0.05)
	assert_true(Session.skipping)
	Session.stop_skipping()
	assert_false(Session.skipping)
	Session._accumulator = 0.0
	Session._process(0.05)
	assert_eq(Session.steps_last_frame, 1, "normal speed again")
	assert_false(sim.world.player().action_queue.is_empty(), "still asleep, just not skipping")
	assert_false(Session.skipping, "not again for this sleep")


func test_a_critical_need_wakes_the_player() -> void:
	# Sleep slows hunger to 3 per hour (T-0036): 15.02 + 0.05 - 0.1 crosses 15 in the first minute.
	var sim := _sleeper("sleep", {"hunger": 15.02})
	var first_boundary := (sim.clock.tick / SimClock.STEPS_PER_GAME_MINUTE + 1) * SimClock.STEPS_PER_GAME_MINUTE
	var notices: Array[String] = []
	var listener := func(text: String) -> void: notices.append(text)
	Session.notice.connect(listener)
	Session._process(0.05)
	Session.notice.disconnect(listener)
	assert_false(Session.skipping, "hunger went critical: stop skipping")
	assert_eq(sim.clock.tick, first_boundary, "stop at the event, without spending the remaining skip budget")
	assert_near(sim.world.player().needs["hunger"], 14.97)
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
	assert_eq(Session.steps_last_frame, TimeSkip.STEPS_PER_FRAME, "the new sleep skips on its own next frame")
	for frame: int in 30:
		if sim.world.player().action_queue.is_empty():
			break
		Session._process(0.05)
	assert_true(sim.world.player().action_queue.is_empty())


func test_the_overlay_says_skipping() -> void:
	var sim := _sleeper("sleep", {"energy": 40.0})
	assert_eq(SkipOverlay.text(sim), "Skipping… %s (Esc to stop)" % sim.clock.format())
