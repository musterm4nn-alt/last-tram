extends TestCase
## T-0051: every float survives a save exactly, even the ones Godot's JSON parser would read
## back a little off.

const ROOM: PackedStringArray = ["#####", "#@..#", "#####"]


func _round_trip(data: Variant) -> Variant:
	var json := JSON.new()
	assert_eq(Ser.parse_json(json, Ser.to_json(data)), OK)
	return json.data


func test_thousands_of_random_floats_come_back_exactly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var values: Array = []
	for i: int in 5000:
		values.append(rng.randf_range(-1000.0, 1000.0) * pow(10.0, rng.randi_range(-4, 4)))
	var back: Array = _round_trip({"values": values})["values"]
	var wrong := 0
	for i: int in values.size():
		if not back[i] is float or back[i] != values[i]:
			wrong += 1
	assert_eq(wrong, 0)


func test_plain_json_would_lose_some_of_them() -> void:
	# The reason for the exact form: without it, some of these come back different.
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var lost := 0
	for i: int in 1000:
		var value := rng.randf_range(0.0, 100.0)
		var json := JSON.new()
		json.parse(JSON.stringify([value], "", false, true))
		if (json.data as Array)[0] != value:
			lost += 1
	assert_true(lost > 0, "Godot's parser is exact now: D26 may be revisited")


func test_simple_numbers_stay_readable() -> void:
	var text := Ser.to_json({"a": 0.5, "b": 4.5, "c": 80.0, "d": 12, "name": "Mira"}, false)
	assert_false(text.contains(Ser.EXACT_PREFIX), text)
	var precise := 100.0
	for i: int in 41:
		precise -= 0.1
	assert_eq(_round_trip([precise])[0], precise)


func test_other_strings_are_left_alone() -> void:
	var odd: Array = ["#f64:zzzzzzzzzzzzzzzz", "#f64:00", "f64:0000000000000000", "Haus 12"]
	assert_eq(_round_trip(odd), odd)


func test_a_save_with_awkward_needs_loads_exactly() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var player := sim.world.player()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for need_id: String in player.needs:
		player.needs[need_id] = rng.randf_range(0.0, 100.0) + 1e-13
	player.pos = Vector2(1.5 + 1e-12, 1.5 - 3e-13)
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	for need_id: String in player.needs:
		assert_eq(loaded.world.player().needs[need_id], player.needs[need_id], need_id)
	assert_eq(loaded.world.player().pos, player.pos)
