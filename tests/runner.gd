extends SceneTree
## Headless test runner. Use tools/test.sh (or tools/check.sh), not this file directly.
##   tools/test.sh                 run everything
##   tools/test.sh --filter=save   only tests whose "file :: name" contains "save"
##
## Finds every tests/**/test_*.gd (except tests/support and tests/fixtures), runs each
## method starting with "test_", and prints one line per test plus a summary.
## A test FAILS if an assertion fails or ANY Godot/script error is logged while it runs.
## The last line is always "LAST_TRAM_TESTS: PASSED" or "LAST_TRAM_TESTS: FAILED".
## (Godot exits with code 0 even when a script fails to parse, so tools look for that line.)

const TESTS_ROOT: String = "res://tests"
const SKIP_DIRS: Array[String] = ["support", "fixtures"]


## Collects every error Godot or a script logs (warnings are ignored).
class ErrorCatcher extends Logger:
	var _mutex: Mutex = Mutex.new()
	var _errors: PackedStringArray = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		_errors.append("%s:%d %s" % [file, line, rationale if not rationale.is_empty() else code])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> PackedStringArray:
		_mutex.lock()
		var out := _errors
		_errors = PackedStringArray()
		_mutex.unlock()
		return out


func _initialize() -> void:
	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	var filter := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.substr("--filter=".length())

	var passed := 0
	var failed: PackedStringArray = []
	print("== Last Tram tests ==")
	for path: String in _find_test_files(TESTS_ROOT):
		var rel := path.trim_prefix(TESTS_ROOT + "/")
		catcher.take()
		var script: GDScript = load(path)
		var load_errors := catcher.take()
		if script == null or not script.can_instantiate() or not load_errors.is_empty():
			if filter.is_empty() or rel.containsn(filter):
				failed.append(rel)
				_report_fail(rel + " (does not load or compile)", load_errors)
			continue
		var instance: Variant = script.new()
		if not instance is TestCase:
			failed.append(rel)
			_report_fail(rel + " (must extend TestCase)", PackedStringArray())
			continue
		var test: TestCase = instance
		for method: Dictionary in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var id := "%s :: %s" % [rel, method_name]
			if not filter.is_empty() and not id.containsn(filter):
				continue
			test.before_each()
			test.call(method_name)
			test.after_each()
			var problems := test.take_problems()
			for error: String in catcher.take():
				problems.append("error logged: " + error)
			if problems.is_empty():
				passed += 1
				print("  ok    " + id)
			else:
				failed.append(id)
				_report_fail(id, problems)

	var ok := failed.is_empty() and passed > 0
	print("== %d passed, %d failed ==" % [passed, failed.size()])
	if passed == 0 and failed.is_empty():
		print("No tests matched" + (" filter '%s'" % filter if not filter.is_empty() else ""))
	for id: String in failed:
		print("FAILED: " + id)
	print("LAST_TRAM_TESTS: " + ("PASSED" if ok else "FAILED"))
	OS.remove_logger(catcher)
	quit(0 if ok else 1)


func _report_fail(what: String, problems: PackedStringArray) -> void:
	print("  FAIL  " + what)
	for problem: String in problems:
		print("        - " + problem)


func _find_test_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub: String in DirAccess.get_directories_at(dir):
		if dir == TESTS_ROOT and sub in SKIP_DIRS:
			continue
		out.append_array(_find_test_files(dir.path_join(sub)))
	for file: String in DirAccess.get_files_at(dir):
		if file.begins_with("test_") and file.ends_with(".gd"):
			out.append(dir.path_join(file))
	out.sort()
	return out
