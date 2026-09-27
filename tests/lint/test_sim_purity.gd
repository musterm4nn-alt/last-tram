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
]


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
			for r: int in regexes.size():
				if regexes[r].search(code) != null:
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
