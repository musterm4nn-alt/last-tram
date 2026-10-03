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


func test_interact_parses_and_skips_the_menu() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--interact=fridge"]))
	assert_eq(options.interact, "fridge")
	assert_true(options.skip_menu())


func test_queue_parses_pairs_and_skips_the_menu() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--queue=fridge:grab_snack,tv:watch_tv"]))
	assert_eq(options.queue.size(), 2)
	if options.queue.size() == 2:
		assert_eq(options.queue[0], PackedStringArray(["fridge", "grab_snack"]))
		assert_eq(options.queue[1], PackedStringArray(["tv", "watch_tv"]))
	assert_true(options.skip_menu())


func test_screen_pause_and_load() -> void:
	var pause := LaunchOptions.parse(PackedStringArray(["--screen=pause"]))
	assert_eq(pause.screen, "pause")
	var load_list := LaunchOptions.parse(PackedStringArray(["--screen=load", "--screenshot=x.png"]))
	assert_eq(load_list.screen, "load")
	assert_false(load_list.skip_menu(), "the Load list lives in the main menu")


func test_creator_options_parse_and_show_the_menu() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--screen=creator", "--creator-tab=body", "--creator-seed=7", "--screenshot=x.png"]))
	assert_eq(options.screen, "creator")
	assert_eq(options.creator_tab, "body")
	assert_eq(options.creator_seed, 7)
	assert_false(options.skip_menu(), "the creator lives behind the main menu")
	assert_eq(LaunchOptions.parse(PackedStringArray([])).creator_seed, -1)


func test_gallery_options_parse() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--screen=gallery", "--gallery-page=2"]))
	assert_eq(options.screen, "gallery")
	assert_eq(options.gallery_page, 2)



## T-0080
func test_art_option() -> void:
	assert_eq(LaunchOptions.parse(PackedStringArray(["--art=kenney"])).art, "kenney")
	assert_eq(LaunchOptions.parse(PackedStringArray([])).art, "", "placeholders by default")


## T-0084
func test_look_at_and_hide_hud() -> void:
	var options := LaunchOptions.parse(PackedStringArray(["--look-at=40,26", "--hide-hud", "--paused"]))
	assert_eq(options.look_at, Vector2i(40, 26))
	assert_true(options.hide_hud)
	assert_true(options.paused)
	assert_true(options.skip_menu(), "--look-at starts straight into the game")
	var plain := LaunchOptions.parse(PackedStringArray([]))
	assert_eq(plain.look_at, LaunchOptions.NO_CELL)
	assert_false(plain.hide_hud)
	assert_false(plain.paused)
