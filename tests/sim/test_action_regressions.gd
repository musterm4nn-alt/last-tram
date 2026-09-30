extends TestCase
## Review regressions: movement owns its route and actions use real elapsed game time.

const ROOM: PackedStringArray = ["............", ".@..........", "............", "............", "............", "............", "............"]


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	assert_true(sim.world.add_object(obj))
	return obj


func _stand(sim: Sim, obj: WorldObject) -> void:
	var cell := obj.slot_cell(sim.content, 0)
	sim.world.player().pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.world.player().free_will = false


func test_walking_away_from_tv_stops_its_need_rates() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(6, 1, 0))
	_stand(sim, tv)
	var player := sim.world.player()
	player.needs["fun"] = 20.0
	sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
	sim.step()
	sim.submit(WalkToCommand.new(player.id, Vector3i(1, 4, 0)))
	sim.run_minutes(2)
	assert_eq(player.cell(), Vector3i(1, 4, 0))
	assert_true(player.action_queue.is_empty())
	assert_near(player.needs["fun"], 19.8)


func test_immediate_walk_cancels_routing_and_later_actions_wait_for_arrival() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(8, 1, 0))
	var player := sim.world.player()
	player.free_will = false
	sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
	sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	var survivor := player.action_queue[1].id
	var destination := Vector3i(1, 5, 0)
	sim.submit(WalkToCommand.new(player.id, destination))
	sim.step()
	assert_eq(player.action_queue.size(), 1)
	assert_eq(player.action_queue[0].id, survivor)
	assert_eq(player.action_queue[0].state, Action.QUEUED)
	assert_eq(player.path.back(), destination)
	for i: int in 100:
		if player.path.is_empty():
			break
		assert_eq(player.action_queue[0].state, Action.QUEUED)
		sim.step()
	assert_eq(player.cell(), destination)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING, "later action resumes after the walk")


func test_a_removed_target_cannot_keep_granting_interaction_benefits() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(6, 1, 0))
	_stand(sim, tv)
	var player := sim.world.player()
	player.needs["fun"] = 20.0
	sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
	sim.step()
	sim.world.remove_object(tv.id)
	sim.run_minutes(2)
	assert_true(player.action_queue.is_empty())
	assert_near(player.needs["fun"], 19.8)


func test_loaded_obsolete_movement_cancels_performing_before_granting_rates() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(6, 1, 0))
	_stand(sim, tv)
	sim.submit(QueueInteractionCommand.new(sim.world.player_id, "watch_tv", tv.id))
	sim.step()
	sim.world.player().path = [Vector3i(1, 5, 0)]
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	loaded.step()
	assert_true(loaded.world.player().action_queue.is_empty())


func test_two_minute_actions_last_forty_steps_at_every_clock_phase() -> void:
	for phase: int in SimClock.STEPS_PER_GAME_MINUTE:
		var sim := SimFactory.from_rows(content(), ROOM)
		var sink := _place(sim, "sink", Vector3i(6, 1, 0))
		_stand(sim, sink)
		sim.clock.tick += phase
		var player := sim.world.player()
		player.needs["hygiene"] = 20.0
		sim.submit(QueueInteractionCommand.new(player.id, "wash_hands", sink.id))
		sim.run_steps(39)
		assert_eq(player.action_queue.size(), 1, "ended too early at phase %d" % phase)
		assert_true(player.needs["hygiene"] < 20.0, "finish reward must wait for full duration")
		sim.step()
		assert_true(player.action_queue.is_empty(), "must finish at exactly forty steps")
		assert_near(player.needs["hygiene"], 30.0 - 2.0 * 4.0 / 60.0)


func test_rates_wait_for_a_full_personal_minute_at_every_clock_phase() -> void:
	for phase: int in SimClock.STEPS_PER_GAME_MINUTE:
		var sim := SimFactory.from_rows(content(), ROOM)
		var tv := _place(sim, "tv", Vector3i(6, 1, 0))
		_stand(sim, tv)
		sim.clock.tick += phase
		var player := sim.world.player()
		player.needs["fun"] = 20.0
		sim.submit(QueueInteractionCommand.new(player.id, "watch_tv", tv.id))
		sim.run_steps(19)
		assert_eq(player.action_queue[0].minutes_done, 0)
		assert_true(player.needs["fun"] <= 20.0, "global minute boundary cannot grant early rates")
		sim.step()
		assert_eq(player.action_queue[0].minutes_done, 1)
		assert_near(player.needs["fun"], 20.0 + 25.0 / 60.0 - 6.0 / 60.0)


func test_sleep_minimum_duration_uses_elapsed_ticks_at_every_clock_phase() -> void:
	for phase: int in SimClock.STEPS_PER_GAME_MINUTE:
		var sim := SimFactory.from_rows(content(), ROOM)
		var bed := _place(sim, "bed_double", Vector3i(4, 1, 0))
		_stand(sim, bed)
		sim.clock.tick += phase
		sim.world.player().needs["energy"] = 99.0
		sim.submit(QueueInteractionCommand.new(sim.world.player_id, "sleep", bed.id))
		sim.run_steps(SimClock.STEPS_PER_GAME_MINUTE * 60 - 1)
		assert_eq(sim.world.player().action_queue.size(), 1, "sleep ended early at phase %d" % phase)
		sim.step()
		assert_true(sim.world.player().action_queue.is_empty())


func test_saving_mid_personal_minute_preserves_duration_and_rates() -> void:
	for phase: int in SimClock.STEPS_PER_GAME_MINUTE:
		var straight := SimFactory.from_rows(content(), ROOM)
		var tv := _place(straight, "tv", Vector3i(6, 1, 0))
		_stand(straight, tv)
		straight.clock.tick += phase
		straight.submit(QueueInteractionCommand.new(straight.world.player_id, "watch_tv", tv.id))
		straight.run_steps(27)
		var loaded := SaveCodec.from_json(SaveCodec.to_json(straight), content())
		assert_true(loaded != null)
		if loaded == null:
			return
		straight.run_minutes(65)
		loaded.run_minutes(65)
		assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(straight))
