extends TestCase
## Guards the most important architecture rule: sim/ is pure, deterministic logic.
## If this test fails, do NOT weaken it. Move the offending code out of sim/ (usually into
## game/), or use the sim equivalent named in the message.

const SIM_DIR: String = "res://sim"
## Only content loading may touch files.
const FILE_ACCESS_ALLOWED_IN: String = "res://sim/content/"

const RULES: Array[Array] = [
	["\\bget_tree\\s*\\(", "no scene tree in sim/ (sim is not a Node)"],
	["\\b(get_node|add_child)\\s*\\(", "no nodes in sim/"],
	["\\bInput\\.", "no input in sim/: game/ turns input into Commands"],
	["\\bTime\\.", "no real time in sim/: use sim.clock"],
	["\\bOS\\.", "no OS access in sim/"],
	["\\bEngine\\.", "no Engine access in sim/"],
	["(?<![\\w.])(randi|randf|randi_range|randf_range|randfn|randomize|seed)\\s*\\(", "no global randomness in sim/: use sim.rng.stream(\"name\")"],
	["\\bawait\\b", "no await in sim/: the sim is synchronous"],
	["^\\s*signal\\s", "no signals in sim/: use sim.emit_event()"],
	["\\bSession\\b", "sim/ must not know about the game layer (Session)"],
	["res://game/", "sim/ must not load anything from game/"],
	["\\.(tscn|scn|png|ogg|wav)\\b", "sim/ must not load scenes, images or sounds"],
	["^\\s*static\\s+var\\b", "no static var in sim/: it outlives a game; use const, or mark an immutable one '# lint-ok: <why>'"],
	["\\b(get_instance_id|instance_from_id)\\s*\\(", "no object identity in sim/: it differs between runs; use int ids"],
	["(?<![\\w.])hash\\s*\\(", "no hash() in sim/: it can differ between runs and versions; mix ints yourself (Autonomy.noise)"],
	["\\bJSON\\.parse(_string)?\\s*\\(", "read JSON with Ser.parse_json (exact numbers, D26)"],
	["\\b(Thread|WorkerThreadPool|Mutex|Semaphore)\\b", "no threads in sim/: the sim is single-threaded and ordered"],
	["(?<![\\w.])(print|prints|printt|print_rich|printerr|printraw)\\s*\\(", "no print in sim/: emit an event"],
	["(?<![\\w.])(exp|pow|log|sin|cos|tan|asin|acos|atan|atan2)\\s*\\(", "no transcendental maths in sim/: results can differ between machines and break replays; use a table (Conversations.logistic)"],
]
## The static var and hash() rules may be waived on a line with this marker and a reason.
const WAIVER: String = "# lint-ok:"
## Rules about file paths look inside strings (the others only at code).
const PATH_RULE_TEXTS: PackedStringArray = ["res://game/", "\\.(tscn|scn|png|ogg|wav)\\b"]
## One sample violation per rule (T-0078): every rule must catch its line.
const SAMPLES: String = "res://tests/fixtures/lint_samples/sim_violations.txt"


func test_sim_code_is_pure() -> void:
	var files := LintUtil.gd_files(SIM_DIR)
	assert_false(files.is_empty())
	var regexes: Array[RegEx] = []
	for rule: Array in RULES:
		regexes.append(RegEx.create_from_string(rule[0]))
	var file_regex := RegEx.create_from_string("\\b(FileAccess|DirAccess)\\b")
	for path: String in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			var code := LintUtil.code_only(lines[n])
			for r: int in _broken(regexes, lines[n]):
				fail("%s:%d %s\n          %s" % [path, n + 1, RULES[r][1], lines[n].strip_edges()])
			if not path.begins_with(FILE_ACCESS_ALLOWED_IN) and file_regex.search(code) != null:
				fail("%s:%d no file access in sim/ outside sim/content/ (game/ does saving)" % [path, n + 1])


func test_sim_classes_extend_refcounted_or_other_sim_classes() -> void:
	var files := LintUtil.gd_files(SIM_DIR)
	var sim_classes: Dictionary = {"RefCounted": true}
	var class_regex := RegEx.create_from_string("^class_name\\s+(\\w+)")
	for path: String in files:
		for line: String in FileAccess.get_file_as_string(path).split("\n"):
			var m := class_regex.search(line)
			if m != null:
				sim_classes[m.get_string(1)] = true
	var extends_regex := RegEx.create_from_string("^\\s*extends\\s+(\\w+)")
	for path: String in files:
		var lines := FileAccess.get_file_as_string(path).split("\n")
		for n: int in lines.size():
			var m := extends_regex.search(lines[n])
			if m != null and not sim_classes.has(m.get_string(1)):
				fail("%s:%d extends %s; sim classes must extend RefCounted or another sim class" % [path, n + 1, m.get_string(1)])


## The indexes of the RULES `line` breaks. Comments never count; strings count only for the
## path rules; the static var and hash() rules are waived by WAIVER.
func _broken(regexes: Array[RegEx], line: String) -> Array[int]:
	var code := LintUtil.code_only(line)
	var with_strings := line.split("#")[0]
	var out: Array[int] = []
	for r: int in regexes.size():
		var text := with_strings if PATH_RULE_TEXTS.has(RULES[r][0]) else code
		var waived := line.contains(WAIVER) and (String(RULES[r][0]).contains("static") or String(RULES[r][0]).contains("hash"))
		if regexes[r].search(text) != null and not waived:
			out.append(r)
	return out


func test_every_rule_catches_its_sample() -> void:
	var regexes: Array[RegEx] = []
	for rule: Array in RULES:
		regexes.append(RegEx.create_from_string(rule[0]))
	var caught: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(SAMPLES).split("\n"):
		if line.strip_edges().is_empty():
			continue
		var broken := _broken(regexes, line)
		assert_false(broken.is_empty(), "the sample isn't caught: " + line)
		for r: int in broken:
			caught[r] = true
	for r: int in RULES.size():
		assert_true(caught.has(r), "no sample for: " + String(RULES[r][1]))
	assert_true(_broken(regexes, "static var _x: RegEx = RegEx.new()  # lint-ok: compiled once").is_empty(), "the waiver works")
	assert_true(_broken(regexes, "var shown := \"print(x)\"  # exp(1) in a comment").is_empty(), "strings and comments don't count")
