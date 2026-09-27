extends TestCase
## Code files must stay small enough to work in (see docs/conventions.md).
## If this test fails, do NOT raise the limit. Split the file by responsibility
## (one class per file, like the ContentDB loaders in sim/content/).

## Every folder with game code (tests are exempt: long test lists are fine).
const CODE_DIRS: Array[String] = ["res://sim", "res://game", "res://tools"]
## Hard ceiling with headroom over the ~300-line convention.
const MAX_LINES: int = 350


func test_code_files_stay_small() -> void:
	for dir: String in CODE_DIRS:
		var files := LintUtil.gd_files(dir)
		assert_false(files.is_empty(), "no scripts found in " + dir)
		for path: String in files:
			var lines := line_count(path)
			assert_true(lines <= MAX_LINES, "%s has %d lines (max %d): split it by responsibility" % [path, lines, MAX_LINES])


## Physical lines in the file (like `wc -l`).
static func line_count(path: String) -> int:
	var text := FileAccess.get_file_as_string(path)
	var count := text.split("\n").size()
	if text.ends_with("\n"):
		count -= 1
	return count
