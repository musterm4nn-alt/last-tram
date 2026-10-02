extends TestCase
## T-0077: the front-page docs tell the truth. The README's status names the roadmap's
## current (▶) milestone, and its key list is the HUD's.

const README: String = "res://README.md"
const ROADMAP: String = "res://docs/roadmap.md"


func test_the_readme_status_matches_the_roadmap() -> void:
	var current := RegEx.create_from_string("^\\| (M\\d+) \\| ([^|]+?) \\|.*\\| ▶ \\|\\s*$")
	var rows: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(ROADMAP).split("\n"):
		var found := current.search(line)
		if found != null:
			rows.append("**%s · %s** is in progress" % [found.get_string(1), found.get_string(2)])
	assert_eq(rows.size(), 1, "the roadmap has exactly one ▶ milestone: %s" % [rows])
	if rows.size() == 1:
		assert_true(FileAccess.get_file_as_string(README).contains(rows[0]), "README.md's Status must say: %s" % rows[0])


func test_the_readme_lists_the_huds_keys() -> void:
	var readme := FileAccess.get_file_as_string(README)
	for command_mode: bool in [false, true]:
		var keys := Hud.hint_text(command_mode).replace("   ", " · ")
		assert_true(readme.contains(keys), "README.md must list the keys as the HUD does:\n%s" % keys)
