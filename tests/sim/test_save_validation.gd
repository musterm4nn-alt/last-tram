extends TestCase
## Review regression: malformed schemas return null and errors without logging/crashing.

const ROOM: PackedStringArray = ["########", "#@.....#", "#......#", "########"]


func _save() -> Dictionary:
	return SaveCodec.to_dict(SimFactory.from_rows(content(), ROOM))


func _reject(data: Dictionary, label: String) -> void:
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_dict(data, content(), errors), null, label)
	assert_false(errors.is_empty(), label)


func test_every_required_root_field_is_validated_before_loading() -> void:
	_reject({"save_version": 2}, "partial v2 save")
	for key: String in ["save_version", "world", "clock", "rng", "pending_commands"]:
		var missing := _save()
		missing.erase(key)
		_reject(missing, "missing " + key)
		for value: Variant in [null, false, "bad", [], -17]:  # -17: never valid (17 became a real save version)
			if key == "pending_commands" and value is Array:
				continue
			var wrong := _save()
			wrong[key] = value
			_reject(wrong, "%s has wrong type %s" % [key, value])


func test_world_grid_and_people_have_required_types_and_references() -> void:
	for key: String in ["grid", "people", "next_id", "player_id"]:
		var missing := _save()
		(missing["world"] as Dictionary).erase(key)
		_reject(missing, "missing world." + key)
	for value: Variant in [null, "bad", 12, [], {"id": 1}]:
		var data := _save()
		data["world"]["people"] = [value]
		_reject(data, "bad person entry")
	var wrong_player := _save()
	wrong_player["world"]["player_id"] = 999
	_reject(wrong_player, "missing player")
	var duplicate := _save()
	duplicate["world"]["people"].append(duplicate["world"]["people"][0].duplicate(true))
	_reject(duplicate, "duplicate person id")
	var reused_id := _save()
	reused_id["world"]["next_id"] = 1
	_reject(reused_id, "entity allocator would reuse an id")


func test_grid_dimensions_levels_and_encoded_bytes_are_validated() -> void:
	for field: String in ["width", "height", "palette", "levels"]:
		var missing := _save()
		(missing["world"]["grid"] as Dictionary).erase(field)
		_reject(missing, "missing grid." + field)
	for dimension: Variant in [0, -1, 1.5, "8", INF, NAN, 1.0e30, []]:
		var data := _save()
		data["world"]["grid"]["width"] = dimension
		_reject(data, "invalid width")
	for levels: Dictionary in [{}, {"floor": "AAAA"}, {"0": "bad base64"}, {"0": 99}, {"0": ""}]:
		var data := _save()
		data["world"]["grid"]["levels"] = levels
		_reject(data, "invalid levels")
	var bad_alphabet := _save()
	var level: String = bad_alphabet["world"]["grid"]["levels"]["0"]
	bad_alphabet["world"]["grid"]["levels"]["0"] = "!" + level.substr(1)
	_reject(bad_alphabet, "decoder must never log for invalid base64")


func test_nested_person_state_never_reaches_unchecked_deserializers() -> void:
	var cases: Dictionary = {
		"pos": [[1], ["x", 1], {}, [INF, 1], [-1, 1]],
		"facing": [[], [1, null]],
		"move_intent": [[], [2, 0]],
		"walk_speed": ["fast", -1],
		"level": ["zero", 1.5],
		"needs": [[], {"hunger": "bad"}, {"hunger": -1}],
		"path": [false, [[1, 2]], [[1, "x", 0]]],
		"action_queue": [false, [17], [{"state": "bad"}]],
		"appearance": [[], {"features": [17]}, {"height_cm": "tall"}],
		"outfit": [[], {"top": 12}, {"top": {"item": []}}],
		"free_will": [1, "yes"],
		"last_input_tick": [-1, 1.0e30],
	}
	for key: String in cases:
		for value: Variant in cases[key]:
			var data := _save()
			data["world"]["people"][0][key] = value
			_reject(data, "bad person." + key)


func test_malformed_rng_and_commands_are_reported() -> void:
	for streams: Variant in [[], {"test": 7}, {"test": "abc"}, {"test": "99999999999999999999999"}]:
		var data := _save()
		data["rng"]["streams"] = streams
		_reject(data, "bad rng streams")
	for command: Variant in [null, 17, {}, {"type": "unknown", "person_id": 1},
		{"type": "walk_to", "person_id": 1, "target": [1]},
		{"type": "set_move_intent", "person_id": 1, "direction": ["x", 1]},
		{"type": "cancel_action", "person_id": 1},
		{"type": "set_free_will", "person_id": 1, "enabled": "yes"},
		{"type": "queue_interaction", "person_id": 1, "target_id": 2}]:
		var data := _save()
		data["pending_commands"] = [command]
		_reject(data, "bad pending command")


func test_v2_action_migration_assigns_ids_and_keeps_legacy_cancellations() -> void:
	var sim := SimFactory.new_game(content(), 7)
	var tv: WorldObject
	for obj: WorldObject in sim.world.objects.values():
		var lot := Lots.lot_at(sim, obj.origin)
		if obj.def_id == "tv" and lot != null and lot.id == sim.world.player().home_lot_id:
			tv = obj  # the player's own TV (T-0055: other homes are private)
	sim.submit(QueueInteractionCommand.new(sim.world.player_id, "watch_tv", tv.id))
	sim.submit(QueueInteractionCommand.new(sim.world.player_id, "watch_tv", tv.id))
	sim.step()
	sim.submit(CancelActionCommand.new(sim.world.player_id, 1))
	var data := SaveCodec.to_dict(sim)
	data["save_version"] = 2
	for action: Dictionary in data["world"]["people"][0]["action_queue"]:
		action.erase("id")
	for command: Dictionary in data["pending_commands"]:
		command.erase("action_id")
	var errors: Array[String] = []
	var loaded := SaveCodec.from_dict(data, content(), errors)
	assert_true(loaded != null, str(errors))
	if loaded == null:
		return
	var queue := loaded.world.player().action_queue
	assert_true(queue[0].id > 0)
	assert_ne(queue[0].id, queue[1].id)
	loaded.step()
	assert_eq(loaded.world.player().action_queue.size(), 1)
	assert_true(errors.is_empty())


func test_wallets_and_the_ledger_are_validated() -> void:
	var bad_wallets: Array[Dictionary] = [
		{"cash": -1, "bank": 0, "statement": []},
		{"cash": 0, "bank": "lots", "statement": []},
		{"cash": 0, "bank": 0.5, "statement": []},
		{"cash": 0, "bank": 0, "statement": [{"tick": 1, "amount": 5, "account": "sock", "reason": "start", "detail": ""}]},
		{"cash": 0, "bank": 0, "statement": "none"},
	]
	for wallet: Dictionary in bad_wallets:
		var data := _save()
		data["world"]["people"][0]["wallet"] = wallet
		_reject(data, "bad wallet %s" % [wallet])
	for ledger: Variant in ["bad", {"sources": {"start": -5}, "sinks": {}}, {"sources": {}, "sinks": {"rent": "x"}}]:
		var data := _save()
		data["world"]["ledger"] = ledger
		_reject(data, "bad ledger %s" % [ledger])


func test_household_groceries_must_be_whole_and_not_negative() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for value: Variant in [-1, 2.5, "lots"]:
		var data := SaveCodec.to_dict(sim)
		data["world"]["households"][0]["groceries"] = value
		_reject(data, "bad groceries %s" % [value])


func test_jobs_are_validated() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for job: Variant in ["clerk", {"job_id": 5}, {"job_id": "office_clerk", "position": -1}, {"job_id": "office_clerk", "performance": 140}]:
		var data := SaveCodec.to_dict(sim)
		data["world"]["people"][0]["job"] = job
		_reject(data, "bad job %s" % [job])
