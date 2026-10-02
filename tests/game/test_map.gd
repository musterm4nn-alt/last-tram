extends TestCase
## T-0048: the minimap and the full town map (M).

const ROOM: PackedStringArray = [
	"#####",
	"#@..#",
	"#####",
]

var _old_content: ContentDB
var _old_sim: Sim
var _old_speed: int = 1
var _old_mode: bool = false


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_speed = Session.speed
	_old_mode = Session.command_mode
	Session.content = content()
	Session.command_mode = false
	InputActions.register()


func after_each() -> void:
	Input.action_release("run")
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	Session.command_mode = _old_mode


func test_map_image_is_one_pixel_per_cell_in_terrain_colours() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	var grid := sim.world.grid
	var image := MapView.map_image(grid, content(), 0)
	assert_eq(image.get_size(), Vector2i(grid.width, grid.height))
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(2, 1), Vector2i(4, 2)]:
		var expected := grid.terrain_def_at(Vector3i(cell.x, cell.y, 0)).debug_color
		assert_true(image.get_pixelv(cell).is_equal_approx(expected), "cell %s" % cell)
	assert_false(image.get_pixel(0, 0).is_equal_approx(image.get_pixel(2, 1)), "wall and floor differ")


func test_view_rect_centres_on_the_player_and_stops_at_every_edge() -> void:
	var map := Vector2(72, 44)
	var view := Vector2(56, 36)
	assert_eq(MapView.view_rect(map, Vector2(36, 22), view), Rect2(Vector2(8, 4), view))
	assert_eq(MapView.view_rect(map, Vector2(1, 1), view), Rect2(Vector2(0, 0), view))
	assert_eq(MapView.view_rect(map, Vector2(71, 43), view), Rect2(Vector2(16, 8), view))
	assert_eq(MapView.view_rect(map, Vector2(1, 43), view), Rect2(Vector2(0, 8), view))


func test_view_rect_centres_a_map_smaller_than_the_view() -> void:
	var view := Vector2(56, 36)
	var shown := MapView.view_rect(Vector2(10, 50), Vector2(9, 0), view)
	assert_eq(shown.position.x, -23.0, "narrow map centred across")
	assert_eq(shown.position.y, 0.0, "tall map still follows down")


func test_every_place_on_the_level_gets_a_label_at_its_centre() -> void:
	var labels := MapView.labels(content(), 0)
	var count := 0
	for district_id: String in content().district_order:
		for place: PlaceDef in content().districts[district_id].places:
			if place.level == 0 and not place.hidden:
				count += 1
	assert_eq(labels.size(), count, "every place but the secret ones (T-0069)")
	var altmarkt: Dictionary = {}
	for label: Dictionary in labels:
		if label["name"] == "Altmarkt":
			altmarkt = label
	assert_eq(altmarkt.get("cell"), Vector2(32, 29), "rect [18, 23, 28, 12]")
	var upstairs := MapView.labels(content(), 1)
	var names: Array[String] = []
	for label: Dictionary in upstairs:
		names.append(label["name"])
	assert_has(names, "Haus 9, 1st floor", "upper floors have their own labels (T-0031)")
	assert_false(names.has("Altmarkt"), "ground-floor places stay on level 0")


func test_fit_scale_is_the_largest_whole_scale_that_fits() -> void:
	assert_eq(TownMap.fit_scale(Vector2i(72, 44), Vector2(1152, 568)), 12)
	assert_eq(TownMap.fit_scale(Vector2i(72, 44), Vector2(20, 20)), 1, "never below 1")


func test_opening_the_map_pauses_and_closing_restores_the_speed() -> void:
	Session.sim = SimFactory.from_rows(content(), ROOM)
	Session.speed = 2
	var town_map := TownMap.new()
	town_map.open()
	assert_true(town_map.is_open)
	assert_true(town_map.visible)
	assert_eq(Session.speed, 0)
	town_map.close()
	assert_false(town_map.is_open)
	assert_eq(Session.speed, 2)
	Session.speed = 0
	town_map.open()
	town_map.close()
	assert_eq(Session.speed, 0, "still paused if it was paused")
	town_map.free()


func test_no_movement_or_running_while_the_map_is_open() -> void:
	Session.sim = SimFactory.from_rows(content(), ROOM)
	var town_map := TownMap.new()
	var controller := PlayerController.new()
	controller.town_map = town_map
	controller.forced_direction = Vector2.RIGHT
	Input.action_press("run")
	town_map.open()
	controller._process(0.0)
	Session.sim.run_steps(5)
	var player := Session.sim.world.player()
	assert_eq(player.move_intent, Vector2.ZERO)
	assert_false(player.running)
	town_map.close()
	controller._process(0.0)
	Session.sim.step()
	assert_eq(player.move_intent, Vector2.RIGHT, "input resumes after closing")
	assert_true(player.running)
	controller.free()
	town_map.free()


func test_hidden_places_appear_once_found() -> void:
	var db := ContentDB.load_default()
	var sim := SimFactory.new_game(db, 1)
	var player := sim.world.player()
	db.place("altmarkt").hidden = true
	var names := func(found: PackedStringArray) -> Array:
		return MapView.labels(db, 0, found).map(func(l: Dictionary) -> String: return l["name"])
	assert_false(names.call(Discoveries.found_places(sim, player)).has("Altmarkt"), "a secret place is off the map")
	player.pos = Vector2(30.5, 30.5)
	assert_eq(Hud.place_text(sim, player), "Altstadt", "and the HUD doesn't name it")
	Discoveries.uncover(sim, player, "fountain_coins")
	var found := Discoveries.found_places(sim, player)
	assert_eq(found, PackedStringArray(["altmarkt"]))
	assert_true(names.call(found).has("Altmarkt"), "found: on the map")
	var marked := MapView.labels(db, 0, found).filter(func(l: Dictionary) -> bool: return l["found"])
	assert_eq(marked.size(), 1, "with a note mark")
	assert_eq(Hud.place_text(sim, player), "Altmarkt")


func test_notebook_lists_leads_and_finds() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_eq(NotebookApp.lines(sim, player.id), PackedStringArray(["Leads", "No leads yet. Talk to people, read notices, look around.", "", "Finds", "Nothing yet."]))
	Discoveries.learn_clue(sim, player, "fountain_coins", "talk")
	assert_eq(NotebookApp.lines(sim, player.id)[1], "Altmarkt: " + content().discovery("fountain_coins").clue)
	Discoveries.uncover(sim, player, "fountain_coins")
	var lines := NotebookApp.lines(sim, player.id)
	assert_eq(lines.slice(3), PackedStringArray(["Finds", "Coins in the fountain (Altmarkt)", "  Found €3.40", "  You fished €3.40 out of the fountain. Nobody saw."]))
	var unlock := DiscoveryEffect.new()
	unlock.kind = DiscoveryEffect.UNLOCK
	unlock.interaction_id = "sit"
	assert_eq(NotebookApp.effect_text(sim, unlock), "You can now: Sit down")
