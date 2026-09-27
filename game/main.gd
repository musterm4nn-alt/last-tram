extends Node2D
## Entry point: builds the 2D view, the HUD and input handling, then starts a new game.
##
## Command-line options (after `--`), used by tools/run.sh and tools/screenshot.sh:
##   --seed=N            world seed (default 1)
##   --load=PATH         load a save file instead of starting a new game
##   --advance=N         run N game minutes before showing anything
##   --walk=X,Y          hold a walking direction, e.g. --walk=1,0 walks east
##   --debug             start with the F3 debug overlay open
##   --zoom=N            start at zoom level N (index into ViewConfig.ZOOM_LEVELS, 0 = widest)
##   --screenshot=PATH   save a PNG after --frames frames, then quit
##   --frames=N          frames to wait before the screenshot (default 20)

var _controller: PlayerController
var _camera: CameraRig2D
var _debug_overlay: DebugOverlay
var _screenshot_path: String = ""
var _screenshot_frames: int = 20
var _frame: int = 0


func _ready() -> void:
	InputActions.register()
	add_child(WorldView2D.new())
	add_child(PeopleView2D.new())
	_camera = CameraRig2D.new()
	add_child(_camera)
	add_child(Hud.new())
	_debug_overlay = DebugOverlay.new()
	add_child(_debug_overlay)
	_controller = PlayerController.new()
	add_child(_controller)
	Session.game_loaded.connect(_controller.reset)

	var args := _parse_args()
	if args.has("load") and Session.load_from(String(args["load"])):
		pass
	else:
		Session.new_game(int(args.get("seed", "1")))
	if args.has("advance"):
		Session.advance_minutes(int(args["advance"]))
	if args.has("walk"):
		var parts := String(args["walk"]).split(",")
		if parts.size() == 2:
			_controller.forced_direction = Vector2(parts[0].to_float(), parts[1].to_float())
	if args.has("debug"):
		_debug_overlay.visible = true
	if args.has("zoom"):
		_camera.set_zoom_index(int(args["zoom"]))
	if args.has("screenshot"):
		_screenshot_path = String(args["screenshot"])
		_screenshot_frames = int(args.get("frames", "20"))


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


## "--seed=5 --debug" -> {"seed": "5", "debug": ""}
func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var eq := arg.find("=")
		if eq < 0:
			out[arg.substr(2)] = ""
		else:
			out[arg.substr(2, eq - 2)] = arg.substr(eq + 1)
	return out
