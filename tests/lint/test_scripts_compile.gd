extends TestCase
## Every script in the project must compile, including view/UI scripts that no other test
## loads. Parse errors are also logged, which fails this test through the runner.

const DIRS: Array[String] = ["res://sim", "res://game", "res://tools", "res://tests"]


func test_every_script_compiles() -> void:
	var count := 0
	for dir: String in DIRS:
		for path: String in LintUtil.gd_files(dir):
			var script: GDScript = load(path)
			count += 1
			if script == null or not script.can_instantiate():
				fail("%s does not compile" % path)
	assert_true(count > 10, "expected to find the project's scripts, found %d" % count)


func test_scenes_load() -> void:
	var scene: PackedScene = load("res://game/main.tscn")
	assert_true(scene != null and scene.can_instantiate(), "game/main.tscn does not load")
