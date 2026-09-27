extends TestCase
## Every command must be registered and survive save/replay encoding.

const COMMANDS_DIR: String = "res://sim/commands"


func test_every_command_is_registered_and_roundtrips() -> void:
	var seen: Dictionary = {}
	for file: String in DirAccess.get_files_at(COMMANDS_DIR):
		if not file.ends_with(".gd"):
			continue
		var script: GDScript = load(COMMANDS_DIR.path_join(file))
		var instance: Variant = script.new()
		if not instance is Command:
			fail("%s does not extend Command" % file)
			continue
		var command: Command = instance
		var type_id := command.type_id()
		assert_false(type_id.is_empty(), "%s: type_id() is empty" % file)
		assert_false(seen.has(type_id), "%s: type_id '%s' is used twice" % [file, type_id])
		seen[type_id] = true
		var created := CommandRegistry.create(type_id)
		assert_true(created != null and created.get_script() == script,
			"%s: add \"%s\" to CommandRegistry.create()" % [file, type_id])
		var encoded := CommandRegistry.encode(command)
		var decoded := CommandRegistry.decode(JSON.parse_string(JSON.stringify(encoded)))
		assert_true(decoded != null, "%s: does not decode" % file)
		if decoded != null:
			assert_eq(Ser.to_json(CommandRegistry.encode(decoded)), Ser.to_json(encoded), "%s: roundtrip" % file)


func test_unknown_command_type_decodes_to_null() -> void:
	assert_eq(CommandRegistry.decode({"type": "no_such_command"}), null)


func test_applied_commands_are_logged_with_their_tick() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#.@.#", "#####"])
	sim.run_steps(3)
	var tick := sim.clock.tick
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.LEFT))
	sim.step()
	var applied := sim.take_applied_commands()
	assert_eq(applied.size(), 1)
	assert_eq(applied[0]["tick"], tick)
	assert_eq(applied[0]["command"]["type"], "set_move_intent")
	assert_true(sim.take_applied_commands().is_empty(), "taking the log clears it")
