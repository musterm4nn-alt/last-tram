extends TestCase
## Guards the view/sim boundary: game/ may READ sim state but must change it only through
## Session.submit(Command). Only Session advances time.
## This catches the obvious cases; reviews catch the rest.

const GAME_DIR: String = "res://game"
const SESSION_FILE: String = "res://game/session.gd"


func test_game_does_not_write_sim_state() -> void:
	# e.g. "Session.sim.world.player().pos = x" or "sim.clock.tick += 1"
	var write := RegEx.create_from_string("\\bsim\\.[\\w.()\\[\\]\"]+\\s*(=|\\+=|-=|\\*=|/=)(?!=)")
	for path: String in LintUtil.gd_files(GAME_DIR):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			var code := LintUtil.code_only(lines[n])
			if write.search(code) != null and not code.strip_edges().begins_with("sim ="):
				fail("%s:%d writes sim state directly; submit a Command instead\n          %s" % [path, n + 1, lines[n].strip_edges()])


func test_only_session_advances_time() -> void:
	var stepping := RegEx.create_from_string("\\.(step|run_steps|run_minutes)\\s*\\(")
	for path: String in LintUtil.gd_files(GAME_DIR):
		if path == SESSION_FILE:
			continue
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			if stepping.search(LintUtil.code_only(lines[n])) != null:
				fail("%s:%d only game/session.gd may step the sim (use Session.advance_minutes)" % [path, n + 1])


## T-0077: tests/sim/ checks behaviour, not wording; tests that need a game/ class (the HUD,
## menus, the inspector) belong in tests/game/.
func test_sim_tests_do_not_use_game_classes() -> void:
	var declared := RegEx.create_from_string("^class_name\\s+(\\w+)")
	var names: PackedStringArray = []
	for path: String in LintUtil.gd_files(GAME_DIR):
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var found := declared.search(line)
			if found != null:
				names.append(found.get_string(1))
	assert_true(names.has("Hud") and names.has("InteractionMenu"), "game/ class names found: %s" % [names])
	var used := RegEx.create_from_string("\\b(%s)\\b" % "|".join(names))
	for path: String in LintUtil.gd_files("res://tests/sim"):
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			var found := used.search(LintUtil.code_only(lines[n]))
			if found != null:
				fail("%s:%d uses %s from game/; move the check to tests/game/" % [path, n + 1, found.get_string(1)])
