class_name TestCase
extends RefCounted
## Base class for all tests. Put tests in tests/<area>/test_<topic>.gd (extends TestCase);
## tests/runner.gd runs every method whose name starts with "test_".
## Assertions record a failure and let the test continue. A test also fails if any Godot
## or script error is logged while it runs.

static var _shared_content: ContentDB

var _problems: PackedStringArray = []


## The real game content (data/), loaded once and shared by all tests. Treat as read-only.
static func content() -> ContentDB:
	if _shared_content == null:
		_shared_content = ContentDB.load_default()
	return _shared_content


## Called before/after every test method. Override if needed.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


# --- Assertions ------------------------------------------------------------------------

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("expected true, got false", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("expected false, got true", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _equal(actual, expected):
		_fail("expected %s, got %s" % [_show(expected), _show(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _equal(actual, unexpected):
		_fail("expected anything but %s" % _show(unexpected), message)


func assert_near(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		_fail("expected %s ± %s, got %s" % [expected, tolerance, actual], message)


func assert_vec_near(actual: Vector2, expected: Vector2, tolerance: float = 0.0001, message: String = "") -> void:
	if actual.distance_to(expected) > tolerance:
		_fail("expected %s ± %s, got %s" % [expected, tolerance, actual], message)


func assert_has(container: Variant, item: Variant, message: String = "") -> void:
	var found := false
	if container is Array or container is Dictionary or container is PackedStringArray or container is String:
		found = item in container
	if not found:
		_fail("expected %s to contain %s" % [_show(container), _show(item)], message)


func fail(message: String) -> void:
	_problems.append(_caller_location() + message)


# --- Runner interface (used by tests/runner.gd) ----------------------------------------

func take_problems() -> PackedStringArray:
	var out := _problems
	_problems = PackedStringArray()
	return out


func _fail(what: String, message: String) -> void:
	var text := what if message.is_empty() else "%s: %s" % [message, what]
	_problems.append(_caller_location() + text)


## "test_movement.gd:42 " for the first stack frame inside a test file.
func _caller_location() -> String:
	for backtrace: ScriptBacktrace in Engine.capture_script_backtraces():
		for i: int in backtrace.get_frame_count():
			var file := backtrace.get_frame_file(i)
			if file.begins_with("res://tests/") and not file.begins_with("res://tests/support/") and file != "res://tests/runner.gd":
				return "%s:%d " % [file.get_file(), backtrace.get_frame_line(i)]
	return ""


static func _equal(a: Variant, b: Variant) -> bool:
	var numeric := [TYPE_INT, TYPE_FLOAT]
	if typeof(a) in numeric and typeof(b) in numeric:
		return a == b
	if typeof(a) != typeof(b):
		return false
	return a == b


static func _show(value: Variant) -> String:
	var text := ("\"%s\"" % value) if value is String or value is StringName else str(value)
	return text if text.length() <= 300 else text.substr(0, 300) + "…"
