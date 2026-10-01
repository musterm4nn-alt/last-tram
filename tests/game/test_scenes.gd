extends TestCase
## T-0043: scenes are requested by the sim and shown by the view, never changing the sim.

const DIR: String = "user://test_t0043_scenes"

var _old_content: ContentDB
var _old_sim: Sim
var _old_speed: int = 1


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_speed = Session.speed
	Session.content = content()


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.speed = _old_speed
	if DirAccess.dir_exists_absolute(DIR):
		for file: String in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file))
		DirAccess.remove_absolute(DIR)


func _load_scenes(scene: Dictionary) -> ContentReader:
	DirAccess.make_dir_recursive_absolute(DIR)
	var file := FileAccess.open(DIR.path_join("s.json"), FileAccess.WRITE)
	file.store_string(Ser.to_json({"scenes": [scene]}))
	file.close()
	var reader := ContentReader.new()
	SceneLoader.load(ContentDB.new(), reader, DIR)
	return reader


func test_scenes_load_and_bad_ones_are_reported() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	assert_true(content().scenes.has("first_night_home"))
	assert_eq(content().interaction("sleep").presentation.scene_id, "first_night_home")
	assert_true(_load_scenes({"id": "ok", "adult": false, "pages": ["{actor} smiles at {target.them}."]}).errors.is_empty())
	assert_false(_load_scenes({"id": "x", "adult": true, "pages": ["Later."]}).errors.is_empty(), "no adult scenes in the core")
	assert_false(_load_scenes({"id": "x", "adult": false, "pages": ["Hi {actor.name}"]}).errors.is_empty(), "unknown placeholder")
	assert_false(_load_scenes({"id": "x", "adult": false, "pages": []}).errors.is_empty(), "no pages")


func test_text_fills_names_places_and_pronouns() -> void:
	var sim := SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	var spec := CharacterSpec.default_player(content())
	spec.first_name = "Sam"
	spec.pronouns = "they"
	var other := SimFactory.spawn_person(sim, Vector3i(3, 1, 0), spec)
	var request := {"actor_id": other.id, "target_id": sim.world.player_id, "place_id": "kneipe_anker"}
	assert_eq(SceneText.fill("{actor} raises {actor.their} glass at {place}.", request, sim), "Sam raises their glass at Kneipe Zum Anker.")
	assert_eq(SceneText.fill("{actor.they} laughs.", request, sim), "They laughs.")
	assert_eq(SceneText.fill("{target} waves.", {"target_id": 999}, sim), "Someone waves.")


func test_the_first_morning_asks_for_the_first_night_scene_only_for_the_player() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var requests: Array[Dictionary] = []
	for minute: int in 2 * SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"scene_requested":
				requests.append(event["data"])
				assert_eq(int(event["data"]["actor_id"]), sim.world.player_id, "only the player's own scenes")
	var first_nights := requests.filter(func(r: Dictionary) -> bool: return r["scene_id"] == "first_night_home")
	assert_eq(first_nights.size(), 1, "once, on the first morning")


func test_scene_requests_do_not_change_the_sim() -> void:
	var a := SimFactory.new_game(content(), 1)
	var b := SimFactory.new_game(content(), 1)
	b.world.player().free_will = true
	a.run_minutes(SimClock.MINUTES_PER_DAY + 120)
	b.run_minutes(SimClock.MINUTES_PER_DAY + 120)
	assert_eq(SaveCodec.to_json(a), SaveCodec.to_json(b), "nothing in the sim depends on scenes being shown")


func test_the_popup_pauses_pages_through_and_queues() -> void:
	Session.sim = SimFactory.new_game(content(), 1)
	Session.speed = 2
	var popup := ScenePopup.new()
	var request := {"scene_id": "first_night_home", "actor_id": Session.sim.world.player_id, "target_id": 0, "place_id": ""}
	popup.request(request)
	popup.request({"scene_id": "coffee_at_wolke", "actor_id": Session.sim.world.player_id})
	popup.request({"scene_id": "no_such_scene"})
	assert_true(popup.is_open)
	assert_eq(Session.speed, 0, "paused while a scene is shown")
	assert_true(popup.text().begins_with("The radiator ticks."))
	popup.next_page()
	assert_true(popup.text().contains(Session.sim.world.player().display_name()), popup.text())
	popup.next_page()
	assert_true(popup.text().begins_with("Café Wolke"), "then the queued scene")
	popup.next_page()
	popup.next_page()
	assert_false(popup.is_open)
	assert_eq(Session.speed, 2, "the speed comes back")
	popup.free()
