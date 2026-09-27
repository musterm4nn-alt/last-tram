extends SceneTree
## Writes a fixture save for tests/fixtures/saves/ with the CURRENT save version.
## Run after bumping SaveCodec.SAVE_VERSION:  tools/make_fixture_save.sh v2_basic
## The fixture is a new game played for a while, so it contains every kind of state that
## a new game has. Extend `_play()` when new systems add new kinds of state.


func _initialize() -> void:
	var fixture_name := "v%d_basic" % SaveCodec.SAVE_VERSION
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--name="):
			fixture_name = arg.substr("--name=".length())
	var content := ContentDB.load_default()
	if not content.is_valid():
		print("Content is invalid; fix it first:\n" + "\n".join(content.errors))
		quit(1)
		return
	var sim := SimFactory.new_game(content, 12345)
	_play(sim)
	var path := "res://tests/fixtures/saves/%s.json" % fixture_name
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(SaveCodec.to_json(sim))
	file.close()
	print("Wrote " + path)
	quit(0)


func _play(sim: Sim) -> void:
	var player_id := sim.world.player_id
	sim.submit(SetMoveIntentCommand.new(player_id, Vector2(1, 0.3)))
	sim.run_minutes(2)
	sim.submit(SetMoveIntentCommand.new(player_id, Vector2(-0.5, -1)))
	sim.run_minutes(90)
	# Leave one command pending so fixtures also cover pending commands.
	sim.submit(SetMoveIntentCommand.new(player_id, Vector2.ZERO))
