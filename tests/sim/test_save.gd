extends TestCase

const FIXTURES_DIR: String = "res://tests/fixtures/saves"

const ROOM: PackedStringArray = [
	"############",
	"#..........#",
	"#..#...@...#",
	"#......#...#",
	"############",
]

## Walking directions the "player" chooses at given ticks (relative to the start tick).
const SCRIPT: Dictionary = {
	0: Vector2(1, 0),
	37: Vector2(0, 1),
	80: Vector2(-1, -1),
	150: Vector2(-1, 0.4),
	260: Vector2.ZERO,
	300: Vector2(0.2, -1),
}


## Steps `sim` from start+from to start+to, submitting SCRIPT commands on the way.
func _drive(sim: Sim, start: int, from: int, to: int) -> void:
	for t: int in range(from, to):
		if SCRIPT.has(t):
			sim.submit(SetMoveIntentCommand.new(sim.world.player_id, SCRIPT[t]))
		sim.step()
	assert_eq(sim.clock.tick, start + to)


func test_save_load_save_is_identical() -> void:
	var sim := SimFactory.new_game(content(), 7)
	_drive(sim, sim.clock.tick, 0, 200)
	var first := SaveCodec.to_json(sim)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(first, content(), errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	assert_eq(SaveCodec.to_json(loaded), first)


func test_same_inputs_give_the_same_world() -> void:
	var a := SimFactory.from_rows(content(), ROOM, 3)
	var b := SimFactory.from_rows(content(), ROOM, 3)
	_drive(a, a.clock.tick, 0, 400)
	_drive(b, b.clock.tick, 0, 400)
	assert_eq(SaveCodec.to_json(a), SaveCodec.to_json(b))


## The key determinism test: playing straight through must equal playing, saving,
## loading and continuing. Fails if any state is missing from the save.
func test_save_and_continue_equals_uninterrupted_run() -> void:
	var straight := SimFactory.from_rows(content(), ROOM, 5)
	var start := straight.clock.tick
	_drive(straight, start, 0, 400)

	var first_half := SimFactory.from_rows(content(), ROOM, 5)
	_drive(first_half, start, 0, 173)
	var resumed := SaveCodec.from_json(SaveCodec.to_json(first_half), content())
	_drive(resumed, start, 173, 400)

	assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight))


func test_pending_commands_survive_saving() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	sim.submit(SetMoveIntentCommand.new(sim.world.player_id, Vector2.LEFT))
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	loaded.step()
	assert_eq(loaded.world.player().move_intent, Vector2.LEFT)


func test_rng_state_survives_saving() -> void:
	var sim := SimFactory.from_rows(content(), ROOM, 11)
	sim.rng.stream("test").randi()
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_eq(loaded.rng.stream("test").randi(), sim.rng.stream("test").randi())
	assert_eq(loaded.rng.stream("new_stream").randi(), sim.rng.stream("new_stream").randi())


func test_terrain_is_saved_by_id_not_by_index() -> void:
	# A save whose palette order differs from data/terrain.json must still load correctly.
	var cells := PackedInt32Array([1, 0])
	var data := {
		"width": 2, "height": 1,
		"palette": ["grass", "wall"],
		"levels": {"0": Marshalls.raw_to_base64(cells.to_byte_array())},
	}
	var grid := WorldGrid.from_dict(data, content())
	assert_eq(grid.terrain_def_at(Vector3i(0, 0, 0)).id, "wall")
	assert_eq(grid.terrain_def_at(Vector3i(1, 0, 0)).id, "grass")


func test_unknown_terrain_in_save_becomes_void() -> void:
	var cells := PackedInt32Array([0])
	var data := {
		"width": 1, "height": 1,
		"palette": ["terrain_that_was_removed"],
		"levels": {"0": Marshalls.raw_to_base64(cells.to_byte_array())},
	}
	var grid := WorldGrid.from_dict(data, content())
	assert_eq(grid.terrain_def_at(Vector3i(0, 0, 0)).id, "void")


func test_rejects_files_that_are_not_saves() -> void:
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_json("{\"hello\": 1}", content(), errors), null)
	assert_false(errors.is_empty())
	errors.clear()
	assert_eq(SaveCodec.from_json("not json at all", content(), errors), null)
	assert_false(errors.is_empty())


func test_rejects_saves_from_a_newer_game() -> void:
	var data := SaveCodec.to_dict(SimFactory.from_rows(content(), ROOM))
	data["save_version"] = SaveCodec.SAVE_VERSION + 1
	var errors: Array[String] = []
	assert_eq(SaveCodec.from_dict(data, content(), errors), null)
	assert_false(errors.is_empty())


## Every fixture save (one per save version, made with that version) must still load.
func test_all_fixture_saves_still_load() -> void:
	var fixtures := 0
	for file: String in DirAccess.get_files_at(FIXTURES_DIR):
		if not file.ends_with(".json"):
			continue
		fixtures += 1
		var errors: Array[String] = []
		var text := FileAccess.get_file_as_string(FIXTURES_DIR.path_join(file))
		var sim := SaveCodec.from_json(text, content(), errors)
		assert_true(sim != null, "%s does not load: %s" % [file, errors])
		if sim != null:
			assert_eq(SaveCodec.to_dict(sim)["save_version"], SaveCodec.SAVE_VERSION)
			sim.run_minutes(10)
	assert_true(fixtures > 0, "no fixture saves (*.json) in " + FIXTURES_DIR)
