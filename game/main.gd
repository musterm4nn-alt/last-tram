extends Node2D
## Entry point: builds the 2D view, the HUD and input handling, then starts a new game.
##
## Command-line options (after `--`), used by tools/run.sh and tools/screenshot.sh:
##   --seed=N            world seed (default 1)
##   --random-character  the new game's player is a random CharacterSpec (seeded by --seed)
##   --load=PATH         load a save file instead of starting a new game
##   --advance=N         run N game minutes before showing anything
##   --walk=X,Y          hold a walking direction, e.g. --walk=1,0 walks east
##   --debug             start with the F3 debug overlay open (once a game loads)
##   --zoom=N            start at zoom level N (index into ViewConfig.ZOOM_LEVELS, 0 = widest)
##   --screenshot=PATH   save a PNG after --frames frames, then quit
##   --frames=N          frames to wait before the screenshot (default 20)
##   --quickstart        skip the menu and start straight into a new game
##   --menu              force the menu even with quickstart options
##   --screen=name       open the name screen directly (with the menu)

var _controller: PlayerController
var _camera: CameraRig2D
var _hud: Hud
var _debug_overlay: DebugOverlay
var _menu: MainMenu
var _name_screen: NameScreen
var _options: LaunchOptions
var _screenshot_path: String = ""
var _screenshot_frames: int = 20
var _frame: int = 0


func _ready() -> void:
	InputActions.register()
	add_child(WorldView2D.new())
	add_child(PeopleView2D.new())
	_camera = CameraRig2D.new()
	add_child(_camera)
	_hud = Hud.new()
	_hud.visible = false
	add_child(_hud)
	_debug_overlay = DebugOverlay.new()
	add_child(_debug_overlay)
	_controller = PlayerController.new()
	add_child(_controller)
	Session.game_loaded.connect(_controller.reset)
	Session.game_loaded.connect(_on_game_loaded)

	_options = LaunchOptions.parse(OS.get_cmdline_user_args())
	if _options.zoom >= 0:
		_camera.set_zoom_index(_options.zoom)
	if not _options.screenshot_path.is_empty():
		_screenshot_path = _options.screenshot_path
		_screenshot_frames = _options.screenshot_frames
	if _options.skip_menu():
		_start_quick()
	else:
		_menu = MainMenu.new()
		add_child(_menu)
		_menu.new_game_requested.connect(_show_name_screen)
		_name_screen = NameScreen.new()
		_name_screen.visible = false
		add_child(_name_screen)
		_name_screen.back_pressed.connect(_show_menu)
		_name_screen.start_pressed.connect(_start_named_game)
		if _options.screen == "name":
			_show_name_screen()


func _process(_delta: float) -> void:
	if _screenshot_path.is_empty():
		return
	_frame += 1
	if _frame >= _screenshot_frames:
		var image := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(_screenshot_path.get_base_dir())
		var error := image.save_png(_screenshot_path)
		print("screenshot %s: %s" % [_screenshot_path, "saved" if error == OK else error_string(error)])
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Session.toggle_pause()
	elif event.is_action_pressed("speed_1"):
		Session.set_speed(1)
	elif event.is_action_pressed("speed_2"):
		Session.set_speed(2)
	elif event.is_action_pressed("speed_3"):
		Session.set_speed(3)
	elif event.is_action_pressed("quicksave"):
		Session.quicksave()
	elif event.is_action_pressed("quickload"):
		Session.quickload()


## "--seed=5 --debug" -> quickstart without the menu; nothing -> main menu.
func _start_quick() -> void:
	if not _options.load_path.is_empty() and Session.load_from(_options.load_path):
		pass
	else:
		var spec: CharacterSpec = null
		if _options.random_character:
			var character_rng := RandomNumberGenerator.new()
			character_rng.seed = _options.seed_value
			spec = CharacterSpec.random(Session.content, character_rng)
		Session.new_game(_options.seed_value, spec)
	if _options.advance_minutes > 0:
		Session.advance_minutes(_options.advance_minutes)
	if _options.walk != Vector2.ZERO:
		_controller.forced_direction = _options.walk


func _show_name_screen() -> void:
	_menu.visible = false
	_name_screen.visible = true
	_name_screen.focus_first_field()


func _show_menu() -> void:
	_name_screen.visible = false
	_menu.visible = true
	_menu.focus_new_game()


func _start_named_game(spec: CharacterSpec) -> void:
	Session.new_game(randi(), spec)


func _on_game_loaded() -> void:
	_hud.visible = true
	if _options != null and _options.debug:
		_debug_overlay.visible = true
	if is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null
	if is_instance_valid(_name_screen):
		_name_screen.queue_free()
		_name_screen = null
