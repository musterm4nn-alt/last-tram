extends TestCase
## T-0032: places become lots with access rules and opening hours.

const DIR: String = "user://test_t0032_lots"
const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"


func after_each() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		for file: String in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute(DIR.path_join(file))
		DirAccess.remove_absolute(DIR)


func _lot(sim: Sim, place_id: String) -> Lot:
	return Lots.by_place(sim.world, place_id)


func _at_hour(hour: int) -> SimClock:
	var clock := SimClock.new()
	clock.tick = SimClock.ticks_for(2, hour, 30)
	return clock


func test_a_new_game_has_one_lot_per_place_with_the_right_access() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var places := 0
	for district_id: String in content().district_order:
		for place: PlaceDef in content().districts[district_id].places:
			places += 1
			assert_true(_lot(sim, place.id) != null, "lot for %s" % place.id)
	assert_eq(sim.world.lots.size(), places)
	assert_eq(_lot(sim, "home_player").access, Lot.PRIVATE)
	assert_eq(_lot(sim, "spaeti_kaya").access, Lot.HOURS)
	assert_eq(_lot(sim, "altmarkt").access, Lot.PUBLIC)
	assert_eq(_lot(sim, "haus_3").access, Lot.PRIVATE)
	assert_eq(sim.world.player().home_lot_id, _lot(sim, "home_player").id)


func test_lots_do_not_change_the_ids_of_objects_or_the_player() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var max_other := 0
	for id: int in sim.world.objects:
		max_other = maxi(max_other, id)
	max_other = maxi(max_other, sim.world.player_id)
	for id: int in sim.world.lots:
		assert_true(id > max_other, "lots are made last")


func test_is_open_for_daytime_and_past_midnight_hours() -> void:
	var day := Lot.new()
	day.access = Lot.HOURS
	day.open_hour = 8
	day.close_hour = 19
	assert_false(Lots.is_open(day, _at_hour(7)))
	assert_true(Lots.is_open(day, _at_hour(8)))
	assert_true(Lots.is_open(day, _at_hour(18)))
	assert_false(Lots.is_open(day, _at_hour(19)))
	var night := Lot.new()
	night.access = Lot.HOURS
	night.open_hour = 18
	night.close_hour = 2
	assert_true(Lots.is_open(night, _at_hour(1)), "open at 01:00")
	assert_false(Lots.is_open(night, _at_hour(3)), "closed at 03:00")
	assert_false(Lots.is_open(night, _at_hour(12)))
	assert_true(Lots.is_open(night, _at_hour(23)))


func test_may_enter_public_always_hours_when_open_private_for_residents() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	assert_true(Lots.may_enter(sim, player, _lot(sim, "altmarkt")))
	assert_true(Lots.may_enter(sim, player, _lot(sim, "home_player")))
	assert_false(Lots.may_enter(sim, player, _lot(sim, "haus_3")))
	var cafe := _lot(sim, "cafe_wolke")  # 8-19
	sim.clock.tick = SimClock.ticks_for(0, 10)
	assert_true(Lots.may_enter(sim, player, cafe))
	sim.clock.tick = SimClock.ticks_for(0, 21)
	assert_false(Lots.may_enter(sim, player, cafe))
	assert_eq(Lots.lot_at(sim, player.cell()), _lot(sim, "home_player"))


func test_free_will_ignores_a_fridge_in_someone_elses_flat() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var own_fridge := 0
	for id: int in sim.world.objects:
		var obj: WorldObject = sim.world.objects[id]
		if obj.def_id == "fridge" and sim.content.place_at(obj.origin).id == "home_player":
			own_fridge = id
	assert_true(_offers(sim, player, own_fridge), "uses the fridge in the player's flat")
	var fridge := WorldObject.new()
	fridge.id = sim.world.new_id()
	fridge.def_id = "fridge"
	fridge.origin = Vector3i(62, 8, 0)
	assert_eq(sim.world.can_place("fridge", fridge.origin, 0), "")
	assert_true(sim.world.add_object(fridge))
	player.pos = Vector2(62.5, 11.5)
	assert_eq(sim.content.place_at(player.cell()).id, "haus_3")
	assert_false(_offers(sim, player, fridge.id), "not in Haus 3")
	player.home_lot_id = _lot(sim, "haus_3").id
	assert_true(_offers(sim, player, fridge.id), "once Haus 3 is home")


func _offers(sim: Sim, person: Person, object_id: int) -> bool:
	for option: Dictionary in Autonomy.candidates(sim, person):
		if option["object_id"] == object_id:
			return true
	return false


func test_lots_and_home_survive_saving_and_loading() -> void:
	var sim := SimFactory.new_game(content(), 3)
	var spaeti := _lot(sim, "spaeti_kaya")
	spaeti.close_hour = 4
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	assert_eq(Ser.to_json(loaded.world.to_dict()["lots"]), Ser.to_json(sim.world.to_dict()["lots"]))
	assert_eq(_lot(loaded, "spaeti_kaya").close_hour, 4)
	assert_eq(loaded.world.player().home_lot_id, sim.world.player().home_lot_id)


func test_a_save_without_lots_gets_them_from_content() -> void:
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	assert_true(sim != null)
	assert_eq(_lot(sim, "spaeti_kaya").access, Lot.HOURS)
	assert_eq(_lot(sim, "spaeti_kaya").open_hour, 8)


func test_saved_lots_of_removed_places_are_dropped() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	(data["world"]["lots"][0] as Dictionary)["place_id"] = "torn_down"
	var replaced_place: String = sim.world.lots[int(data["world"]["lots"][0]["id"])].place_id
	var loaded := SaveCodec.from_json(JSON.stringify(data), content())
	assert_true(loaded != null)
	assert_eq(Lots.by_place(loaded.world, "torn_down"), null, "the removed place's lot is gone")
	assert_eq(loaded.world.lots.size(), sim.world.lots.size(), "one lot per place again")
	assert_true(Lots.by_place(loaded.world, replaced_place) != null, "its place got a fresh lot (T-0031)")


func test_a_bad_saved_lot_access_is_rejected() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	(data["world"]["lots"][0] as Dictionary)["access"] = "vip"
	assert_eq(SaveCodec.from_json(JSON.stringify(data), content()), null)


func _district(place: Dictionary) -> ContentReader:
	DirAccess.make_dir_recursive_absolute(DIR)
	var level := FileAccess.open(DIR.path_join("level_0.txt"), FileAccess.WRITE)
	level.store_string("......\n......\n......\n")
	level.close()
	var base := {"id": "lots", "name": "Lots", "kind": "shop", "level": 0, "rect": [0, 0, 6, 3]}
	base.merge(place, true)
	var file := FileAccess.open(DIR.path_join("district.json"), FileAccess.WRITE)
	file.store_string(Ser.to_json({"id": "lots", "name": "Lots", "origin": [0, 0],
		"levels": {"0": "level_0.txt"}, "player_spawn": [1, 1, 0], "places": [base]}))
	file.close()
	var reader := ContentReader.new()
	WorldLoader.load_district(content(), reader, DIR, "lots")
	return reader


func test_content_validation_of_access_and_hours() -> void:
	assert_true(_district({"access": "hours", "hours": [8, 20]}).errors.is_empty())
	assert_true(_district({"kind": "public", "access": "public"}).errors.is_empty())
	var unknown := "\n".join(_district({"access": "vip"}).errors)
	assert_true(unknown.contains("access 'vip'"), unknown)
	var missing := "\n".join(_district({"access": "hours"}).errors)
	assert_true(missing.contains("needs \"hours\""), missing)
	var shop_without := "\n".join(_district({}).errors)
	assert_true(shop_without.contains("needs \"hours\""), "a shop must give hours: " + shop_without)
	assert_false(_district({"access": "hours", "hours": [8, 25]}).errors.is_empty(), "hour 25")
	assert_false(_district({"access": "hours", "hours": [8]}).errors.is_empty(), "one hour")
	assert_false(_district({"kind": "home", "hours": [8, 20]}).errors.is_empty(), "hours on a home")
	assert_true(content().errors.is_empty(), "%s" % [content().errors])


func test_closed_days_are_saved_and_older_lots_have_none() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content(), errors)
	assert_true(loaded != null, "%s" % [errors])
	if loaded != null:
		assert_eq(Lots.by_place(loaded.world, "cafe_wolke").closed_days, PackedInt32Array([6]))
	# A save whose lots were made before T-0056 keeps them as they were.
	var data := SaveCodec.to_dict(sim)
	for lot: Dictionary in data["world"]["lots"]:
		lot.erase("closed_days")
	var before := SaveCodec.from_dict(data, content(), errors)
	assert_true(before != null, "%s" % [errors])
	if before != null:
		assert_true(Lots.by_place(before.world, "cafe_wolke").closed_days.is_empty())
	# Saves from before lots (v3) get their lots, closed days included, from content.
	var old := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content(), errors)
	assert_true(old != null, "%s" % [errors])
	if old != null:
		assert_eq(Lots.by_place(old.world, "cafe_wolke").closed_days, PackedInt32Array([6]))
