extends TestCase
## T-0025: free will. The idle player looks after their own needs, input holds autonomy
## back, it can be switched off, and it saves and replays exactly.

const ROOM: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]


## Every need at 100, then `needs`.
func _set_needs(person: Person, needs: Dictionary) -> void:
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 100.0
	for need_id: String in needs:
		person.needs[need_id] = float(needs[need_id])


## Runs `minutes` game minutes and returns the player's autonomy_chose events.
func _run_choices(sim: Sim, minutes: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in minutes:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"autonomy_chose" and int(event["data"]["person_id"]) == sim.world.player_id:
				out.append(event)
	return out


func _object_id(sim: Sim, def_id: String) -> int:
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == def_id:
			return obj.id
	return 0


func test_a_hungry_idle_player_goes_and_eats() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_set_needs(player, {"hunger": 20.0})
	var first := _run_choices(sim, 11)
	assert_false(first.is_empty(), "free will should act within 11 minutes")
	if not first.is_empty():
		assert_has(["grab_snack", "cook_meal"], String(first[0]["data"]["interaction_id"]))
	_run_choices(sim, 49)
	assert_true(player.needs["hunger"] > 20.0, "hunger should be higher after an hour: %s" % player.needs["hunger"])


func test_free_will_off_does_nothing() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_set_needs(player, {"hunger": 20.0})
	sim.submit(SetFreeWillCommand.new(player.id, false))
	assert_true(_run_choices(sim, 120).is_empty())
	assert_true(player.action_queue.is_empty())


func test_input_holds_free_will_back_for_ten_minutes() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_set_needs(player, {"hunger": 20.0})
	sim.submit(SetMoveIntentCommand.new(player.id, Vector2.ZERO))
	assert_true(_run_choices(sim, 9).is_empty(), "nothing before 10 idle minutes")
	assert_false(_run_choices(sim, 2).is_empty(), "something by minute 11")


func test_every_player_command_counts_as_input() -> void:
	var commands: Array[Command] = [
		SetMoveIntentCommand.new(0, Vector2.ZERO),
		WalkToCommand.new(0, Vector3i(2, 1, 0)),
		QueueInteractionCommand.new(0, "no_such_thing", 9999),
		CancelActionCommand.new(0, 5),
	]
	for command: Command in commands:
		var sim := SimFactory.from_rows(content(), ROOM)
		var player := sim.world.player()
		command.set("person_id", player.id)
		sim.run_minutes(3)
		var tick := sim.clock.tick
		sim.submit(command)
		sim.step()
		assert_eq(player.last_input_tick, tick, "%s should record the input tick" % command.type_id())
	# Switching free will is a setting, not input: the tick stays at the spawn.
	var sim2 := SimFactory.from_rows(content(), ROOM)
	var spawned_at := sim2.world.player().last_input_tick
	assert_eq(spawned_at, sim2.clock.tick, "a new game counts as fresh input")
	sim2.run_minutes(3)
	sim2.submit(SetFreeWillCommand.new(sim2.world.player_id, false))
	sim2.step()
	assert_eq(sim2.world.player().last_input_tick, spawned_at)


func test_a_content_player_does_nothing() -> void:
	var sim := SimFactory.new_game(content(), 1)
	_set_needs(sim.world.player(), {})
	assert_true(_run_choices(sim, 60).is_empty())


func test_free_will_never_adds_to_a_queue() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	_set_needs(player, {"hunger": 20.0, "comfort": 40.0})
	sim.submit(QueueInteractionCommand.new(player.id, "sit", _object_id(sim, "sofa")))
	var finished := false
	for i: int in 60:
		sim.run_minutes(1)
		var chosen := false
		for event: Dictionary in sim.events.drain():
			if int(event["data"].get("person_id", -1)) != player.id:
				continue  # the residents live their own lives
			if event["type"] == &"autonomy_chose":
				chosen = true
			elif event["type"] == &"action_finished":
				finished = true
		# Choosing again in the minute the sit ends is fine; before that it is not.
		if finished:
			break
		assert_false(chosen, "free will chose while the player was busy (minute %d)" % i)
	assert_true(finished, "the sit should finish within the hour")


func test_save_and_continue_equals_an_uninterrupted_day() -> void:
	var straight := SimFactory.new_game(content(), 1)
	_set_needs(straight.world.player(), {"hunger": 20.0, "fun": 30.0})
	straight.run_minutes(180)
	var split := SimFactory.new_game(content(), 1)
	_set_needs(split.world.player(), {"hunger": 20.0, "fun": 30.0})
	split.run_minutes(90)
	var errors: Array[String] = []
	var resumed := SaveCodec.from_json(SaveCodec.to_json(split), content(), errors)
	assert_true(resumed != null, "load failed: %s" % [errors])
	if resumed == null:
		return
	resumed.run_minutes(90)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_free_will_fields_are_saved_with_defaults_for_old_saves() -> void:
	var person := Person.new()
	person.free_will = false
	person.last_input_tick = 123
	var copy := Person.from_dict(person.to_dict())
	assert_false(copy.free_will)
	assert_eq(copy.last_input_tick, 123)
	var old := person.to_dict()
	old.erase("free_will")
	old.erase("last_input_tick")
	var loaded := Person.from_dict(old)
	assert_true(loaded.free_will)
	assert_eq(loaded.last_input_tick, 0)


func test_a_day_alone_keeps_every_need_above_zero() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var lowest: Dictionary = {}
	for need_def: NeedDef in content().needs:
		lowest[need_def.id] = 100.0
	for minute: int in 1440:
		sim.run_minutes(1)
		for need_id: String in lowest:
			lowest[need_id] = minf(float(lowest[need_id]), float(player.needs[need_id]))
	print("    lowest needs over one day with free will: %s" % [lowest])
	for need_id: String in lowest:
		assert_true(float(lowest[need_id]) > 0.0, "%s reached 0" % need_id)
