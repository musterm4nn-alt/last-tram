extends TestCase
## T-0006: interactions queue, perform over game minutes, finish or cancel.

const ROOM: PackedStringArray = [
	"............",
	".@..........",
	"............",
	"............",
	"............",
	"............",
	"............",
]

const BROKEN_FILE: String = "res://tests/fixtures/content_broken/interactions/broken.json"


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	assert_true(sim.world.add_object(obj), "could not place %s at %s" % [def_id, cell])
	return obj


## Moves `person` onto use slot `index` of `obj` (same level).
func _stand_on_slot(sim: Sim, person: Person, obj: WorldObject, index: int) -> void:
	var cell := obj.slot_cell(sim.content, index)
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)


func _queue(sim: Sim, person_id: int, interaction_id: String, target_id: int) -> void:
	sim.submit(QueueInteractionCommand.new(person_id, interaction_id, target_id))


## Drains the event log and returns only action_* events.
func _action_events(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if String(event["type"]).begins_with("action_"):
			out.append(event)
	return out


func test_sleep_runs_until_energy_full() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(2, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, bed, 0)
	player.needs["energy"] = 20.0
	var _drained: Array[Dictionary] = sim.events.drain()
	_queue(sim, player.id, "sleep", bed.id)
	sim.step()
	var started := _action_events(sim)
	assert_eq(started.size(), 2)
	if started.size() == 2:
		assert_eq(started[0]["type"], &"action_queued")
		assert_eq(started[1]["type"], &"action_started")
	assert_eq(player.action_queue.size(), 1)
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	assert_eq(player.action_queue[0].slot_index, 0)
	assert_true(player.action_queue[0].started_tick >= 0)
	assert_eq(player.facing, Vector2.RIGHT)
	var sequence: Array[String] = ["action_queued", "action_started"]
	var finished: Dictionary = {}
	for i: int in 750:
		sim.run_minutes(1)
		for event: Dictionary in _action_events(sim):
			sequence.append(String(event["type"]))
			if String(event["type"]) == "action_finished":
				finished = event
		if not finished.is_empty():
			break
	assert_true(not finished.is_empty(), "sleep never finished")
	assert_eq(sequence, ["action_queued", "action_started", "action_finished"])
	if not finished.is_empty():
		assert_true(int((finished["data"] as Dictionary)["minutes"]) >= 60)
		assert_eq(int((finished["data"] as Dictionary)["person_id"]), player.id)
		assert_eq(String((finished["data"] as Dictionary)["interaction_id"]), "sleep")
	assert_true(player.action_queue.is_empty(), "queue should be empty after sleep")
	assert_true(float(player.needs["energy"]) >= 99.9, "energy just after sleep: %s" % player.needs["energy"])


func test_sleep_runs_at_least_min_minutes_even_when_already_rested() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(2, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, bed, 0)
	player.needs["energy"] = 99.0
	_queue(sim, player.id, "sleep", bed.id)
	# Energy is full after about 5 minutes, but sleep lasts min_minutes (60).
	sim.run_minutes(59)
	assert_eq(player.action_queue.size(), 1, "sleep ended before min_minutes")
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.run_minutes(1)
	assert_true(player.action_queue.is_empty(), "sleep should end at min_minutes once energy is full")
	var finished := _action_events(sim)
	assert_eq(finished.size(), 1)
	if finished.size() == 1:
		assert_eq(int((finished[0]["data"] as Dictionary)["minutes"]), 60)


func test_sleep_stops_at_max_minutes_even_when_not_rested() -> void:
	var db := ContentDB.load_default()
	db.interaction("sleep").max_minutes = 90
	var sim := SimFactory.from_rows(db, ROOM)
	var bed := _place(sim, "bed_double", Vector3i(2, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, bed, 0)
	player.needs["energy"] = 20.0
	_queue(sim, player.id, "sleep", bed.id)
	sim.run_minutes(89)
	assert_eq(player.action_queue.size(), 1, "sleep ended before max_minutes")
	sim.run_minutes(1)
	assert_true(player.action_queue.is_empty(), "sleep should end at max_minutes")
	assert_true(float(player.needs["energy"]) < 100.0, "energy cannot be full after 90 minutes from 20")


func test_grab_snack_takes_five_minutes_and_adds_hunger() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, fridge, 0)
	player.needs["hunger"] = 50.0
	var _drained: Array[Dictionary] = sim.events.drain()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	var begun := _action_events(sim)
	assert_eq(begun.size(), 2)
	sim.run_minutes(4)
	assert_eq(player.action_queue.size(), 1)
	assert_eq(player.action_queue[0].minutes_done, 4)
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	assert_near(float(player.needs["hunger"]), 50.0 - 4.0 * 6.0 / 60.0, 0.001)
	sim.run_minutes(1)
	assert_true(player.action_queue.is_empty(), "grab_snack should finish after 5 minutes")
	assert_near(float(player.needs["hunger"]), 50.0 - 5.0 * 6.0 / 60.0 + 25.0, 0.001)
	var finished := _action_events(sim)
	assert_eq(finished.size(), 1)
	if finished.size() == 1:
		assert_eq(finished[0]["type"], &"action_finished")
		assert_eq(int((finished[0]["data"] as Dictionary)["minutes"]), 5)


func test_watch_tv_rates_stack_with_decay() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(8, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, tv, 0)
	player.needs["fun"] = 50.0
	player.needs["comfort"] = 50.0
	_queue(sim, player.id, "watch_tv", tv.id)
	sim.run_minutes(60)
	assert_true(player.action_queue.is_empty(), "watch_tv should finish after 60 minutes")
	assert_near(float(player.needs["fun"]), 50.0 + 25.0 - 6.0, 0.01)
	assert_near(float(player.needs["comfort"]), 50.0 - 2.0 - 8.0, 0.01)


func test_not_on_slot_fails_and_queue_moves_on() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	var failed := _action_events(sim)
	assert_eq(failed.size(), 3)
	if failed.size() == 3:
		assert_eq(failed[0]["type"], &"action_queued")
		assert_eq(failed[1]["type"], &"action_queued")
		assert_eq(failed[2]["type"], &"action_failed")
		assert_eq(String((failed[2]["data"] as Dictionary)["reason"]), "not_at_slot")
	assert_eq(player.action_queue.size(), 1)
	assert_eq(player.action_queue[0].state, Action.QUEUED)
	_stand_on_slot(sim, player, fridge, 0)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	var started := _action_events(sim)
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0]["type"], &"action_started")


func test_queue_limit_and_invalid_commands_are_ignored() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, fridge, 0)
	for i: int in Person.MAX_QUEUE:
		_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue.size(), Person.MAX_QUEUE)
	var queued := _action_events(sim)
	assert_eq(queued.size(), Person.MAX_QUEUE + 1)
	_queue(sim, player.id, "grab_snack", fridge.id)
	_queue(sim, player.id, "sleep", fridge.id)
	_queue(sim, player.id, "no_such_interaction", fridge.id)
	_queue(sim, player.id, "grab_snack", 9999)
	_queue(sim, 9999, "grab_snack", fridge.id)
	sim.submit(CancelActionCommand.new(player.id, 99))
	sim.step()
	assert_eq(player.action_queue.size(), Person.MAX_QUEUE)
	assert_true(_action_events(sim).is_empty(), "invalid commands must be ignored silently")


func test_cancel_performing_stops_it() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(8, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, tv, 0)
	player.needs["fun"] = 80.0
	_queue(sim, player.id, "watch_tv", tv.id)
	sim.run_minutes(2)
	var at_cancel: float = float(player.needs["fun"])
	var _begun: Array[Dictionary] = sim.events.drain()
	sim.submit(CancelActionCommand.new(player.id, 0))
	sim.step()
	var cancelled := _action_events(sim)
	assert_eq(cancelled.size(), 1)
	if cancelled.size() == 1:
		assert_eq(cancelled[0]["type"], &"action_cancelled")
		assert_eq(String((cancelled[0]["data"] as Dictionary)["reason"]), "player")
		assert_eq(String((cancelled[0]["data"] as Dictionary)["interaction_id"]), "watch_tv")
	assert_true(player.action_queue.is_empty())
	sim.run_minutes(5)
	assert_near(float(player.needs["fun"]), at_cancel - 5.0 * 6.0 / 60.0, 0.01)
	assert_true(_action_events(sim).is_empty(), "a cancelled action must never finish")


func test_cancel_front_starts_the_next_action() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var tv := _place(sim, "tv", Vector3i(8, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, tv, 0)
	_queue(sim, player.id, "watch_tv", tv.id)
	_queue(sim, player.id, "watch_tv", tv.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.submit(CancelActionCommand.new(player.id, 0))
	sim.step()
	assert_eq(player.action_queue.size(), 1)
	var events := _action_events(sim)
	assert_eq(events.size(), 2)
	if events.size() == 2:
		assert_eq(events[0]["type"], &"action_cancelled")
		assert_eq(events[1]["type"], &"action_started")
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	assert_eq(player.action_queue[0].minutes_done, 0)


func test_offered_by_and_slot_at_person() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	var offered := Interactions.offered_by(sim, fridge.id)
	assert_eq(offered.size(), 1)
	if offered.size() == 1:
		assert_eq(offered[0].id, "grab_snack")
	assert_true(Interactions.offered_by(sim, 9999).is_empty())
	assert_eq(Interactions.slot_at_person(sim, player, fridge.id), -1)
	assert_eq(Interactions.slot_at_person(sim, player, 9999), -1)
	_stand_on_slot(sim, player, fridge, 0)
	assert_eq(Interactions.slot_at_person(sim, player, fridge.id), 0)


func test_save_while_performing_continues_uninterrupted() -> void:
	var straight := SimFactory.from_rows(content(), ROOM, 5)
	var straight_tv := _place(straight, "tv", Vector3i(8, 1, 0))
	_stand_on_slot(straight, straight.world.player(), straight_tv, 0)
	_queue(straight, straight.world.player_id, "watch_tv", straight_tv.id)
	straight.run_minutes(70)
	var split := SimFactory.from_rows(content(), ROOM, 5)
	var split_tv := _place(split, "tv", Vector3i(8, 1, 0))
	_stand_on_slot(split, split.world.player(), split_tv, 0)
	_queue(split, split.world.player_id, "watch_tv", split_tv.id)
	split.run_minutes(10)
	var mid := split.world.player()
	assert_eq(mid.action_queue.size(), 1)
	assert_eq(mid.action_queue[0].state, Action.PERFORMING)
	assert_eq(mid.action_queue[0].minutes_done, 10)
	var errors: Array[String] = []
	var resumed := SaveCodec.from_json(SaveCodec.to_json(split), content(), errors)
	assert_true(resumed != null, "load failed: %s" % [errors])
	if resumed == null:
		return
	resumed.run_minutes(60)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_broken_interactions_are_reported() -> void:
	var db := ContentDB.load_default()
	assert_true(db.is_valid(), "real content must be valid: %s" % ["\n".join(db.errors)])
	var reader := ContentReader.new()
	InteractionLoader.load_file(db, reader, BROKEN_FILE)
	var all := "\n".join(reader.errors)
	# One check per broken entry, so each rule is proven on its own.
	assert_true(_has_error(reader.errors, "bad_need", "unknown need 'no_such_need' in 'need_rates'"), all)
	assert_true(_has_error(reader.errors, "both_times", "exactly one of"), all)
	assert_true(_has_error(reader.errors, "neither_time", "exactly one of"), all)
	assert_true(_has_error(reader.errors, "bad_need_elsewhere", "unknown need 'no_such_need' in 'until_need'"), all)
	assert_true(_has_error(reader.errors, "bad_need_elsewhere", "unknown need 'ghost_need' in 'finish_needs'"), all)
	assert_true(_has_error(reader.errors, "bad_need_elsewhere", "unknown need 'phantom_need' in 'advertise'"), all)
	assert_true(_has_error(reader.errors, "ghost_tag", "tag 'no_such_tag' is used by no object"), all)
	assert_true(db.interaction("sleep") != null, "the broken file must not clobber real content")


## True if one error names interaction `id` and contains `text`.
func _has_error(errors: Array[String], id: String, text: String) -> bool:
	for error: String in errors:
		if error.contains("interaction '%s'" % id) and error.contains(text):
			return true
	return false
