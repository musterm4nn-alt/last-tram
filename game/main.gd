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
##   --screen=creator    open the character creator directly (with the menu); "name" is the same
##   --creator-tab=TAB   the creator's tab: name, identity, body, face, clothes, personality
##   --creator-seed=N    start the creator from a random character (for repeatable screenshots)
##   --screen=gallery    show every look option (portraits and figures); --gallery-page=2 for clothes
##   --screen=load       open the main menu's Load list (with the menu)
##   --screen=pause      open the Esc menu after the quick start
##   --screen=map        open the full map (M) after the quick start
##   --level=N           show floor N after the quick start (if the world has it)
##   --inspect           open the person inspector on the first resident
##   --phone=APP         open the phone on an app after the quick start (Bank, Contacts, home)
##   --scene=ID          show that scene (as the player) after the quick start
##   --command           start in command mode (Tab)
##   --walk-to=X,Y       send the player walking to cell X,Y (on their level) at the start
##   --interact=DEF_ID   open the interaction menu on the first object of that kind (the
##                       player's own, if their home has one)
##   --queue=DEF:ACTION,...  queue actions at the start, e.g. --queue=fridge:grab_snack,tv:watch_tv
##   --art=SET           draw with the art set data/art2d/SET.json (default: placeholders)

var _controller: PlayerController
var _interaction_menu: InteractionMenu
var _camera: CameraRig2D
var _hud: Hud
var _debug_overlay: DebugOverlay
var _pause_menu: PauseMenu
var _town_map: TownMap
var _phone: Phone
var _scene_popup: ScenePopup
var _wardrobe: WardrobeScreen
var _shop: ShopScreen
var _menu: MainMenu
var _creator: CharacterCreator
var _options: LaunchOptions
var _screenshot_path: String = ""
var _screenshot_frames: int = 20
var _frame: int = 0
## --interact: the def id whose menu opens once the window has settled (then "").
var _interact_on: String = ""
var _frames_seen: int = 0


func _ready() -> void:
	InputActions.register()
	add_child(WorldView2D.new())
	add_child(PathMarker2D.new())
	add_child(DepthLayer2D.new())
	_camera = CameraRig2D.new()
	add_child(_camera)
	add_child(BubblesLayer.new())
	_hud = Hud.new()
	_hud.visible = false
	add_child(_hud)
	_debug_overlay = DebugOverlay.new()
	add_child(_debug_overlay)
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_town_map = TownMap.new()
	add_child(_town_map)
	_phone = Phone.new()
	_phone.town_map = _town_map
	add_child(_phone)
	_scene_popup = ScenePopup.new()
	add_child(_scene_popup)
	_wardrobe = WardrobeScreen.new()
	add_child(_wardrobe)
	_shop = ShopScreen.new()
	add_child(_shop)
	add_child(SkipOverlay.new())
	# A popup is a Window: under a CanvasLayer it keeps its normal size (under this Node2D it
	# would inherit the camera's zoom).
	_interaction_menu = InteractionMenu.new()
	_hud.add_child(_interaction_menu)
	_controller = PlayerController.new()
	_controller.camera = _camera
	_controller.menu = _interaction_menu
	_controller.pause_menu = _pause_menu
	_controller.town_map = _town_map
	_controller.scene_popup = _scene_popup
	_controller.inspector = _hud.inspector
	add_child(_controller)
	Session.game_loaded.connect(_controller.reset)
	Session.game_loaded.connect(_on_game_loaded)

	_options = LaunchOptions.parse(OS.get_cmdline_user_args())
	if not _options.art.is_empty():
		WorldView2D.art = ArtSet.load_set(_options.art, Session.content)
		for problem: String in WorldView2D.art.errors:
			push_warning("Art set: %s" % problem)
	if _options.zoom >= 0:
		_camera.set_zoom_index(_options.zoom)
	if not _options.screenshot_path.is_empty():
		_screenshot_path = _options.screenshot_path
		_screenshot_frames = _options.screenshot_frames
	if _options.screen == "gallery":
		add_child(LookGallery.new(_options.gallery_page))
		return
	if _options.skip_menu():
		_start_quick()
	else:
		_menu = MainMenu.new()
		add_child(_menu)
		_menu.new_game_requested.connect(_show_creator)
		_creator = CharacterCreator.new()
		if _options.creator_seed >= 0:
			var creator_rng := RandomNumberGenerator.new()
			creator_rng.seed = _options.creator_seed
			_creator.start_from(CharacterSpec.random(Session.content, creator_rng))
			_creator.use_seed(_options.creator_seed)
		_creator.visible = false
		add_child(_creator)
		_creator.back_pressed.connect(_show_menu)
		_creator.start_pressed.connect(_start_named_game)
		if _options.screen == "name" or _options.screen == "creator":
			_show_creator()
			_creator.show_tab(_options.creator_tab)
		elif _options.screen == "load":
			_menu.show_load_list()


func _process(_delta: float) -> void:
	if is_instance_valid(_debug_overlay):
		ObjectView2D.show_slots = _debug_overlay.visible
	_frames_seen += 1
	# Popups close when the window's focus changes, which happens a few frames after startup.
	if not _interact_on.is_empty() and _frames_seen >= 12:
		_open_menu_on(_interact_on)
		_interact_on = ""
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
	if _scene_popup.is_open:
		return  # its button takes Enter and Space
	for screen: Variant in [_wardrobe, _shop]:
		if screen.is_open:
			if event.is_action_pressed("menu"):
				get_viewport().set_input_as_handled()
				screen.close()
			return
	if Session.skipping and event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		Session.stop_skipping()  # Esc ends a skip before it opens the menu (T-0078)
		return
	if _town_map.is_open and (event.is_action_pressed("menu") or event.is_action_pressed("map")):
		get_viewport().set_input_as_handled()
		_town_map.close()
		return
	if _phone.is_open and event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		_phone.close()
		return
	if event.is_action_pressed("menu") and _can_toggle_pause_menu():
		get_viewport().set_input_as_handled()
		if _pause_menu.is_open:
			_pause_menu.close()
		else:
			_pause_menu.open()
		return
	if event.is_action_pressed("bug_report") and Session.sim != null:
		_write_bug_report()
		return
	if _pause_menu.is_open or _town_map.is_open:
		return
	if event.is_action_pressed("map") and _can_toggle_pause_menu():
		get_viewport().set_input_as_handled()
		_town_map.open()
	elif event.is_action_pressed("phone") and Session.sim != null:
		get_viewport().set_input_as_handled()
		_phone.toggle()
	elif event.is_action_pressed("pause"):
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
	elif event.is_action_pressed("toggle_command_mode") and Session.sim != null:
		Session.set_command_mode(not Session.command_mode)


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
	# Commands for screenshots go in before --advance, so the advance plays them out.
	var player := Session.sim.world.player()
	if _options.walk_to != LaunchOptions.NO_CELL and player != null:
		Session.submit(WalkToCommand.new(player.id, Vector3i(_options.walk_to.x, _options.walk_to.y, player.level)))
	for pair: PackedStringArray in _options.queue:
		var object_id := _first_object(pair[0])
		if object_id > 0 and player != null:
			Session.submit(QueueInteractionCommand.new(player.id, pair[1], object_id))
	if _options.advance_minutes > 0:
		Session.advance_minutes(_options.advance_minutes)
	if _options.walk != Vector2.ZERO:
		_controller.forced_direction = _options.walk
	if _options.command_mode:
		Session.set_command_mode(true)
	_interact_on = _options.interact
	if _options.screen == "pause":
		_pause_menu.open()
	elif _options.screen == "map":
		_town_map.open()
	if _options.level != LaunchOptions.NO_LEVEL:
		Session.view_level(_options.level)
	if not _options.scene.is_empty():
		_scene_popup.request({"scene_id": _options.scene, "actor_id": Session.sim.world.player_id, "target_id": 0, "place_id": ""})
	if not _options.phone.is_empty():
		_phone.open()
		if _options.phone != "home":
			_phone.show_app(_options.phone)
	if _options.inspect:
		var ids: Array = Session.sim.world.people.keys()
		ids.sort()
		for id: int in ids:
			if id != Session.sim.world.player_id:
				_hud.inspector.show_person(id)
				break


## F9: saves a bug report folder (see Session.write_bug_report) and says where it went.
func _write_bug_report() -> void:
	var image := get_viewport().get_texture().get_image()
	var folder := Session.write_bug_report(image)
	if folder.is_empty():
		Session.notice.emit("Bug report failed")
		return
	print("Bug report saved: %s" % folder)
	Session.notice.emit("Bug report saved: %s" % folder.get_file())


## Esc opens or closes the Esc menu only during a game, with no menu screen up and the
## interaction menu closed (its own Esc closes it first).
func _can_toggle_pause_menu() -> bool:
	if Session.sim == null or is_instance_valid(_menu):
		return false
	if is_instance_valid(_creator) and _creator.visible:
		return false
	return not _interaction_menu.visible


## Opens the interaction menu on the first object with this def id, at its screen position.
func _open_menu_on(def_id: String) -> void:
	var id := _first_object(def_id)
	if id <= 0:
		return
	var obj := Session.sim.world.get_object(id)
	var centre := Vector2(obj.origin.x + 0.5, obj.origin.y + 0.5) * ViewConfig.TILE_PX
	_interaction_menu.open_for(id, get_viewport().get_canvas_transform() * centre)


## The lowest id of an object with this def id in the player's home, else in the town, or 0
## (so --queue=wardrobe:change_clothes uses the player's own wardrobe).
func _first_object(def_id: String) -> int:
	var world := Session.sim.world
	var player := world.player()
	if player != null:
		for id: int in world.objects_on_lot(player.home_lot_id):
			if world.objects[id].def_id == def_id:
				return id
	var ids: Array = world.objects.keys()
	ids.sort()
	for id: int in ids:
		if world.objects[id].def_id == def_id:
			return id
	return 0


func _show_creator() -> void:
	_menu.visible = false
	_creator.visible = true
	_creator.focus_first_field()


func _show_menu() -> void:
	_creator.visible = false
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
	if is_instance_valid(_creator):
		_creator.queue_free()
		_creator = null
