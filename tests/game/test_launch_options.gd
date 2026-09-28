extends TestCase
## T-0020: command-line options parse, and skip_menu() keeps tools out of the menu.


func test_no_arguments_shows_the_menu() -> void:
	var options := LaunchOptions.parse(PackedStringArray([]))
	assert_false(options.skip_menu())


func test_every_option_parses() -> void:
	var options := LaunchOptions.parse(PackedStringArray([
		"--seed=3",
		"--random-character",
		"--load=user://saves/quicksave.json",
		"--advance=90",
		"--walk=1,-0.5",
		"--debug",
		"--zoom=4",
		"--screenshot=out/x.png",
		"--frames=40",
		"--quickstart",
		"--menu",
		"--screen=name",
	]))
	assert_eq(options.seed_value, 3)
	assert_true(options.seed_given)
	assert_true(options.random_character)
	assert_eq(options.load_path, "user://saves/quicksave.json")
	assert_eq(options.advance_minutes, 90)
	assert_eq(options.walk, Vector2(1, -0.5))
	assert_true(options.debug)
	assert_eq(options.zoom, 4)
	assert_eq(options.screenshot_path, "out/x.png")
	assert_eq(options.screenshot_frames, 40)
	assert_true(options.quickstart)
	assert_true(options.menu)
	assert_eq(options.screen, "name")


func test_screenshot_skips_the_menu_unless_forced() -> void:
	assert_true(LaunchOptions.parse(PackedStringArray(["--screenshot=x"])).skip_menu())
	assert_false(LaunchOptions.parse(PackedStringArray(["--menu", "--screenshot=x"])).skip_menu())


func test_seed_skips_the_menu() -> void:
	assert_true(LaunchOptions.parse(PackedStringArray(["--seed=3"])).skip_menu())


func test_quickstart_options_skip_the_menu() -> void:
	assert_true(LaunchOptions.parse(PackedStringArray(["--quickstart"])).skip_menu())
	assert_true(LaunchOptions.parse(PackedStringArray(["--load=x"])).skip_menu())
	assert_true(LaunchOptions.parse(PackedStringArray(["--advance=10"])).skip_menu())
	assert_true(LaunchOptions.parse(PackedStringArray(["--walk=1,0"])).skip_menu())
	assert_true(LaunchOptions.parse(PackedStringArray(["--random-character"])).skip_menu())


func test_screen_name_is_kept() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--menu", "--screen=name"]))
	assert_eq(options.screen, "name")
	assert_false(options.skip_menu())


func test_command_mode_and_walk_to_parse_and_skip_the_menu() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--command", "--walk-to=40,22"]))
	assert_true(options.command_mode)
	assert_eq(options.walk_to, Vector2i(40, 22))
	assert_true(LaunchOptions.parse(PackedStringArray(["--command"])).skip_menu())
	assert_true(LaunchOptions.parse(PackedStringArray(["--walk-to=40,22"])).skip_menu())
	assert_eq(LaunchOptions.parse(PackedStringArray([])).walk_to, LaunchOptions.NO_CELL)

