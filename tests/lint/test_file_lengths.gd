extends TestCase
## sim/ files must stay small enough to work in (see docs/conventions.md).
## If this test fails, do NOT raise the limit. Split the file by responsibility
## (one class per file, like the ContentDB loaders in sim/content/).

const SIM_DIR: String = "res://sim"
## Hard ceiling with headroom over the ~300-line convention.
const MAX_LINES: int = 350


func test_sim_files_stay_small() -> void:
	var files := LintUtil.gd_files(SIM_DIR)
	assert_false(files.is_empty())
	for path: String in files:
		assert_true(line_count(path) <= MAX_LINES, "%s has %d lines (max %d)" % [path, line_count(path), MAX_LINES])


## Physical lines in the file (like `wc -l`).
static func line_count(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	var count := text.split("\n").size()
	if text.ends_with("\n"):
		count -= 1
	return count
