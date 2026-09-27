extends TestCase
## Needs decay, critical events, mood, and saving (T-0005).

const ROOM: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]

const BROKEN_CONTENT: String = "res://tests/fixtures/content_broken"
const V1_SAVE: String = "res://tests/fixtures/saves/v1_basic.json"


func test_needs_drop_by_decay_per_hour_after_sixty_minutes() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var before: Dictionary = {}
	for need_def: NeedDef in content().needs:
		before[need_def.id] = float(player.needs.get(need_def.id, 0.0))
	sim.run_minutes(60)
	for need_def: NeedDef in content().needs:
		var expected: float = float(before[need_def.id]) - need_def.decay_per_hour
		assert_near(float(player.needs[need_def.id]), expected, 0.000001, need_def.id)


func test_needs_stay_within_zero_and_hundred() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		var start_value: float = float(player.needs[need_def.id])
		assert_true(start_value >= 0.0 and start_value <= 100.0, need_def.id)
	sim.run_minutes(3 * SimClock.MINUTES_PER_DAY)
	for need_def: NeedDef in content().needs:
		var value: float = float(player.needs[need_def.id])
		assert_true(value >= 0.0, "%s below 0: %s" % [need_def.id, value])
		assert_true(value <= 100.0, "%s above 100: %s" % [need_def.id, value])


func test_need_critical_fires_exactly_once_on_crossing() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 80.0
	player.needs["hunger"] = 15.05
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.run_minutes(1)
	var first: Array[Dictionary] = sim.events.drain()
	var hunger_events: Array[Dictionary] = []
	for event: Dictionary in first:
		if String(event["type"]) == "need_critical" and String((event["data"] as Dictionary)["need"]) == "hunger":
			hunger_events.append(event)
	assert_eq(hunger_events.size(), 1)
	if hunger_events.size() == 1:
		assert_eq(int((hunger_events[0]["data"] as Dictionary)["person_id"]), player.id)
	sim.run_minutes(5)
	var second: Array[Dictionary] = sim.events.drain()
	var late: int = 0
	for event: Dictionary in second:
		if String(event["type"]) == "need_critical" and String((event["data"] as Dictionary)["need"]) == "hunger":
			late += 1
	assert_eq(late, 0)


func test_no_critical_when_already_below_threshold() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 80.0
	player.needs["hunger"] = 10.0
	var _drained: Array[Dictionary] = sim.events.drain()
	sim.run_minutes(1)
	var events: Array[Dictionary] = sim.events.drain()
	var hunger_count: int = 0
	for event: Dictionary in events:
		if String(event["type"]) == "need_critical" and String((event["data"] as Dictionary)["need"]) == "hunger":
			hunger_count += 1
	assert_eq(hunger_count, 0)


func test_mood_full_needs_is_fine() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	var mood_value: float = Mood.compute(player, content())
	assert_near(mood_value, 20.0, 0.000001)
	assert_eq(Mood.label(mood_value), "Fine")


func test_mood_one_empty_need_lowers_by_thirty_times_weight() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	player.needs["hunger"] = 0.0
	var hunger_def: NeedDef = content().need("hunger")
	var expected_hunger: float = 20.0 - 30.0 * hunger_def.urgency_weight
	assert_near(Mood.compute(player, content()), expected_hunger, 0.000001)
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	player.needs["bladder"] = 0.0
	var bladder_def: NeedDef = content().need("bladder")
	var expected_bladder: float = 20.0 - 30.0 * bladder_def.urgency_weight
	assert_near(Mood.compute(player, content()), expected_bladder, 0.000001)


func test_mood_more_empty_needs_is_lower() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 100.0
	var full: float = Mood.compute(player, content())
	player.needs["hunger"] = 0.0
	var one_empty: float = Mood.compute(player, content())
	player.needs["bladder"] = 0.0
	var two_empty: float = Mood.compute(player, content())
	assert_true(one_empty < full, "%s should be below %s" % [one_empty, full])
	assert_true(two_empty < one_empty, "%s should be below %s" % [two_empty, one_empty])
	for need_def: NeedDef in content().needs:
		player.needs[need_def.id] = 0.0
	var all_empty: float = Mood.compute(player, content())
	assert_near(all_empty, -100.0, 0.000001)
	assert_eq(Mood.label(all_empty), "Miserable")


func test_mood_labels() -> void:
	assert_eq(Mood.label(20.0), "Fine")
	assert_eq(Mood.label(100.0), "Fine")
	assert_eq(Mood.label(19.9), "Okay")
	assert_eq(Mood.label(0.0), "Okay")
	assert_eq(Mood.label(-0.1), "Uneasy")
	assert_eq(Mood.label(-40.0), "Uneasy")
	assert_eq(Mood.label(-40.1), "Miserable")


func test_needs_survive_save_load() -> void:
	var sim := SimFactory.from_rows(content(), ROOM, 5)
	sim.run_minutes(100)
	var before: Dictionary = {}
	for need_def: NeedDef in content().needs:
		before[need_def.id] = float(sim.world.player().needs[need_def.id])
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	for need_def: NeedDef in content().needs:
		assert_near(float(loaded.world.player().needs[need_def.id]), float(before[need_def.id]), 0.000001, need_def.id)


func test_save_mid_run_equals_uninterrupted_run_with_needs() -> void:
	var straight := SimFactory.from_rows(content(), ROOM, 5)
	straight.run_minutes(200)
	var first_half := SimFactory.from_rows(content(), ROOM, 5)
	first_half.run_minutes(73)
	var resumed := SaveCodec.from_json(SaveCodec.to_json(first_half), content())
	resumed.run_minutes(200 - 73)
	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_v1_fixture_save_gets_start_values() -> void:
	var text := FileAccess.get_file_as_string(V1_SAVE)
	assert_false(text.is_empty(), "missing fixture " + V1_SAVE)
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(text, content(), errors)
	assert_true(sim != null, "load failed: %s" % [errors])
	if sim == null:
		return
	for id: int in sim.world.people:
		var person: Person = sim.world.people[id]
		for need_def: NeedDef in content().needs:
			assert_true(person.needs.has(need_def.id), "missing need " + need_def.id)
			assert_near(float(person.needs[need_def.id]), need_def.start, 0.000001, need_def.id)


func test_broken_need_definition_is_rejected() -> void:
	var db := ContentDB.new()
	db.load_from(BROKEN_CONTENT)
	var all := "\n".join(db.errors)
	assert_false(db.is_valid())
	assert_true(all.contains("duplicate need id"), all)
	assert_true(all.contains("'decay_per_hour' must be >= 0"), all)
	assert_true(all.contains("'start' must be within 0..100"), all)
	assert_true(all.contains("'urgency_weight' must be > 0"), all)
	assert_true(all.contains("'critical_below' must be within 0..100"), all)
