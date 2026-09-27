extends TestCase
## T-0007: queued interactions walk to a free use slot first (QUEUED -> ROUTING ->
## PERFORMING); two people never share a slot; direct input cancels with "moved".

const ROOM: PackedStringArray = [
	"............",
	".@..........",
	"............",
	"............",
	"............",
	"............",
	"............",
]

const WALLED: PackedStringArray = [
	"#######",
	"#@.#..#",
	"#..#..#",
	"#..#..#",
	"#######",
]


func _place(sim: Sim, def_id: String, cell: Vector3i) -> WorldObject:
	var obj := WorldObject.new()
	obj.id = sim.world.new_id()
	obj.def_id = def_id
	obj.origin = cell
	obj.rotation = 0
	assert_true(sim.world.add_object(obj), "could not place %s at %s" % [def_id, cell])
	return obj


func _queue(sim: Sim, person_id: int, interaction_id: String, target_id: int) -> void:
	sim.submit(QueueInteractionCommand.new(person_id, interaction_id, target_id))


## An extra adult standing on `cell` with full starting needs.
func _extra(sim: Sim, cell: Vector3i) -> Person:
	var person := Person.new()
	person.id = sim.world.new_id()
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = need_def.start
	sim.world.add_person(person)
	return person


## Moves `person` onto use slot `index` of `obj` (same level).
func _stand_on_slot(sim: Sim, person: Person, obj: WorldObject, index: int) -> void:
	var cell := obj.slot_cell(sim.content, index)
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)


## Drains the event log and returns only action_* events.
func _action_events(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if String(event["type"]).begins_with("action_"):
			out.append(event)
	return out


## Fails the test if two people route to or perform on the same slot.
func _assert_no_shared_slots(sim: Sim) -> void:
	var seen: Dictionary = {}
	for person: Person in sim.world.people.values():
		if person.action_queue.is_empty():
			continue
		var front: Action = person.action_queue[0]
		if front.state != Action.ROUTING and front.state != Action.PERFORMING:
			continue
		if front.slot_index < 0:
			continue
		var key := "%d:%d" % [front.target_id, front.slot_index]
		assert_true(not seen.has(key), "slot %s shared by %d and %d at tick %d" % [key, seen.get(key, -1), person.id, sim.clock.tick])
		seen[key] = person.id


func test_walks_to_fridge_slot_and_finishes_in_order() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var slot_cell := fridge.slot_cell(sim.content, 0)
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	var first := _action_events(sim)
	assert_eq(first.size(), 2)
	if first.size() == 2:
		assert_eq(first[0]["type"], &"action_queued")
		assert_eq(first[1]["type"], &"action_routing")
		assert_eq(int((first[1]["data"] as Dictionary)["slot_index"]), 0)
		assert_eq(int((first[1]["data"] as Dictionary)["target_id"]), fridge.id)
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	assert_false(player.path.is_empty(), "routing must set a path")
	var sequence: Array[String] = []
	for event: Dictionary in first:
		sequence.append(String(event["type"]))
	var finished := false
	for i: int in 30:
		sim.run_minutes(1)
		for event: Dictionary in _action_events(sim):
			sequence.append(String(event["type"]))
			if String(event["type"]) == "action_finished":
				finished = true
		if finished:
			break
	assert_true(finished, "grab_snack never finished: %s" % [sequence])
	assert_eq(sequence, ["action_queued", "action_routing", "action_started", "action_finished"])
	assert_true(player.action_queue.is_empty())
	assert_vec_near(player.pos, Vector2(slot_cell.x + 0.5, slot_cell.y + 0.5), 0.0001)
	assert_eq(player.facing, Vector2.UP)


func test_two_sleepers_use_different_slots_and_third_fails_no_free_slot() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(4, 2, 0))
	var tv := _place(sim, "tv", Vector3i(8, 1, 0))
	var player := sim.world.player()
	var friend := _extra(sim, Vector3i(1, 4, 0))
	var watcher := _extra(sim, Vector3i(8, 3, 0))
	assert_eq(watcher.cell(), tv.slot_cell(sim.content, 0))
	_queue(sim, watcher.id, "watch_tv", tv.id)
	_queue(sim, player.id, "sleep", bed.id)
	_queue(sim, friend.id, "sleep", bed.id)
	sim.step()
	assert_eq(watcher.action_queue[0].state, Action.PERFORMING)
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	assert_eq(friend.action_queue[0].state, Action.ROUTING)
	assert_has([0, 1], player.action_queue[0].slot_index)
	assert_has([0, 1], friend.action_queue[0].slot_index)
	assert_ne(player.action_queue[0].slot_index, friend.action_queue[0].slot_index)
	var _drained: Array[Dictionary] = sim.events.drain()
	var late := _extra(sim, Vector3i(2, 5, 0))
	_queue(sim, late.id, "watch_tv", tv.id)
	sim.step()
	var failed := _action_events(sim)
	assert_eq(failed.size(), 2)
	if failed.size() == 2:
		assert_eq(failed[0]["type"], &"action_queued")
		assert_eq(failed[1]["type"], &"action_failed")
		assert_eq(String((failed[1]["data"] as Dictionary)["reason"]), "no_free_slot")
	assert_true(late.action_queue.is_empty(), "failed action must be popped")


func test_slot_behind_wall_fails_no_path() -> void:
	var sim := SimFactory.from_rows(content(), WALLED)
	var fridge := _place(sim, "fridge", Vector3i(5, 1, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	var failed := _action_events(sim)
	assert_eq(failed.size(), 2)
	if failed.size() == 2:
		assert_eq(failed[0]["type"], &"action_queued")
		assert_eq(failed[1]["type"], &"action_failed")
		assert_eq(String((failed[1]["data"] as Dictionary)["reason"]), "no_path")
	assert_true(player.action_queue.is_empty(), "failed action must be popped")


func test_move_intent_during_routing_cancels_with_moved() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	assert_false(player.path.is_empty())
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.RIGHT))
	sim.step()
	var cancelled := _action_events(sim)
	assert_eq(cancelled.size(), 1)
	if cancelled.size() == 1:
		assert_eq(cancelled[0]["type"], &"action_cancelled")
		assert_eq(String((cancelled[0]["data"] as Dictionary)["reason"]), "moved")
		assert_eq(String((cancelled[0]["data"] as Dictionary)["interaction_id"]), "grab_snack")
	assert_true(player.action_queue.is_empty())
	assert_true(player.path.is_empty(), "cancelled routing must drop the path")
	assert_eq(player.move_intent, Vector2.RIGHT)


func test_move_intent_during_performing_cancels_with_moved() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_stand_on_slot(sim, player, fridge, 0)
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.UP))
	sim.step()
	var cancelled := _action_events(sim)
	assert_eq(cancelled.size(), 1)
	if cancelled.size() == 1:
		assert_eq(cancelled[0]["type"], &"action_cancelled")
		assert_eq(String((cancelled[0]["data"] as Dictionary)["reason"]), "moved")
	assert_true(player.action_queue.is_empty())
	assert_true(player.path.is_empty(), "the person stops following the path")


func test_blocked_route_reroutes_and_finishes() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var slot_cell := fridge.slot_cell(sim.content, 0)
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	assert_true(player.path.size() >= 3, "route too short to block: %s" % [player.path])
	var blocker := WorldObject.new()
	blocker.id = sim.world.new_id()
	blocker.def_id = "fridge"
	blocker.origin = player.path[1]
	blocker.rotation = 0
	assert_true(sim.world.add_object(blocker), "could not block %s" % player.path[1])
	var _drained: Array[Dictionary] = sim.events.drain()
	var routings := 0
	var blocked := 0
	var finished := false
	for i: int in 40:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"action_routing":
				routings += 1
			elif event["type"] == &"path_blocked":
				blocked += 1
			elif event["type"] == &"action_finished":
				finished = true
		if finished:
			break
	assert_true(blocked >= 1, "the walk should have hit the placed object")
	assert_true(routings >= 1, "the action should have routed again after path_blocked")
	assert_true(finished, "the action should still finish after re-routing")
	assert_true(player.action_queue.is_empty())
	assert_vec_near(player.pos, Vector2(slot_cell.x + 0.5, slot_cell.y + 0.5), 0.0001)


func test_three_queued_actions_complete_in_order() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(2, 1, 0))
	var tv := _place(sim, "tv", Vector3i(6, 1, 0))
	var sofa := _place(sim, "sofa", Vector3i(9, 4, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	_queue(sim, player.id, "watch_tv", tv.id)
	_queue(sim, player.id, "sit", sofa.id)
	var finished_order: Array[String] = []
	for i: int in 150:
		sim.run_minutes(1)
		for event: Dictionary in _action_events(sim):
			if String(event["type"]) == "action_finished":
				finished_order.append(String((event["data"] as Dictionary)["interaction_id"]))
		if finished_order.size() == 3:
			break
	assert_eq(finished_order, ["grab_snack", "watch_tv", "sit"])
	assert_true(player.action_queue.is_empty(), "all three actions should be done")


func test_save_during_routing_continues_uninterrupted() -> void:
	var straight := SimFactory.from_rows(content(), ROOM, 5)
	var straight_fridge := _place(straight, "fridge", Vector3i(6, 1, 0))
	_queue(straight, straight.world.player_id, "grab_snack", straight_fridge.id)
	straight.run_steps(400)
	var split := SimFactory.from_rows(content(), ROOM, 5)
	var split_fridge := _place(split, "fridge", Vector3i(6, 1, 0))
	_queue(split, split.world.player_id, "grab_snack", split_fridge.id)
	split.run_steps(10)
	var mid := split.world.player()
	assert_eq(mid.action_queue[0].state, Action.ROUTING)
	assert_false(mid.path.is_empty(), "the save must really be mid-route")
	var errors: Array[String] = []
	var resumed := SaveCodec.from_json(SaveCodec.to_json(split), content(), errors)
	assert_true(resumed != null, "load failed: %s" % [errors])
	if resumed == null:
		return
	resumed.run_steps(390)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_random_queues_never_share_a_slot() -> void:
	var sim := SimFactory.from_rows(content(), ROOM, 11)
	var bed := _place(sim, "bed_double", Vector3i(3, 1, 0))
	var fridge := _place(sim, "fridge", Vector3i(7, 1, 0))
	var tv := _place(sim, "tv", Vector3i(9, 1, 0))
	var sofa := _place(sim, "sofa", Vector3i(4, 4, 0))
	var people: Array[Person] = [sim.world.player(), _extra(sim, Vector3i(1, 4, 0)), _extra(sim, Vector3i(10, 4, 0))]
	var options: Array = [
		["sleep", bed.id],
		["grab_snack", fridge.id],
		["watch_tv", tv.id],
		["sit", sofa.id],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for minute: int in 120:
		for person: Person in people:
			var want := 3 - person.action_queue.size()
			for k: int in want:
				var pick: Array = options[rng.randi_range(0, options.size() - 1)]
				sim.submit(QueueInteractionCommand.new(person.id, String(pick[0]), int(pick[1])))
		sim.run_minutes(1)
		_assert_no_shared_slots(sim)


func test_routes_to_the_nearest_free_slot() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(4, 2, 0))
	var player := sim.world.player()
	# Slot 0 is west of the bed (3,2), slot 1 east (6,2): stand nearer slot 1.
	player.pos = Vector2(8.5, 2.5)
	_queue(sim, player.id, "sleep", bed.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.ROUTING)
	assert_eq(player.action_queue[0].slot_index, 1, "the east slot is nearer")


func test_rerouting_while_standing_on_another_free_slot_uses_it() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var bed := _place(sim, "bed_double", Vector3i(4, 2, 0))
	var player := sim.world.player()
	# Routing to slot 0 with an emptied path, while standing on slot 1 (6,2).
	var action := Action.new("sleep", bed.id)
	action.state = Action.ROUTING
	action.slot_index = 0
	player.action_queue.append(action)
	player.pos = Vector2(6.5, 2.5)
	var start := player.pos
	sim.run_steps(2)
	assert_eq(action.state, Action.PERFORMING)
	assert_eq(action.slot_index, 1, "a free slot underfoot counts as distance 0")
	assert_vec_near(player.pos, start)


func test_removed_target_fails_and_stops_the_walk() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_false(player.path.is_empty())
	sim.world.remove_object(fridge.id)
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.step()
	var events := _action_events(sim)
	assert_eq(events.size(), 1)
	if events.size() == 1:
		assert_eq(events[0]["type"], &"action_failed")
	assert_true(player.action_queue.is_empty())
	assert_true(player.path.is_empty(), "a failed route must stop the walk")


func test_starting_on_a_slot_snaps_to_its_centre() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	var cell := fridge.slot_cell(sim.content, 0)
	player.pos = Vector2(cell.x + 0.8, cell.y + 0.3)
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_eq(player.action_queue[0].state, Action.PERFORMING)
	assert_vec_near(player.pos, Vector2(cell.x + 0.5, cell.y + 0.5), 0.0001)


func test_cancelling_a_routing_action_stops_the_walk() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var fridge := _place(sim, "fridge", Vector3i(6, 1, 0))
	var player := sim.world.player()
	_queue(sim, player.id, "grab_snack", fridge.id)
	sim.step()
	assert_false(player.path.is_empty())
	sim.submit(CancelActionCommand.new(player.id, 0))
	sim.step()
	assert_true(player.action_queue.is_empty())
	assert_true(player.path.is_empty(), "cancelling the walk to an object must stop the walk")
	var stopped := player.pos
	sim.run_steps(10)
	assert_vec_near(player.pos, stopped)

