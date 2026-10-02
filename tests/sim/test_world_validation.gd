extends TestCase
## Review regressions: malformed structured world content reports field errors safely.

const DIR: String = "user://test_review_world_validation"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_write("level_0.txt", "......\n......\n......\n......\n......\n")


func after_each() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	DirAccess.remove_absolute(DIR)


func _write(filename: String, text: String) -> void:
	var file := FileAccess.open(DIR.path_join(filename), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _district() -> Dictionary:
	return {"id": "review", "name": "Review", "origin": [0, 0], "levels": {"0": "level_0.txt"},
		"player_spawn": [1, 1, 0], "places": [{"id": "room", "name": "Room", "kind": "home", "level": 0, "rect": [0, 0, 6, 5], "rent": 10000}]}


func _load(data: Variant) -> ContentReader:
	_write("district.json", Ser.to_json(data))
	var reader := ContentReader.new()
	WorldLoader.load_district(content(), reader, DIR, "review")
	return reader


func test_bad_place_entries_report_an_error_instead_of_casting() -> void:
	for value: Variant in [17, null, "bad", []]:
		var data := _district()
		data["places"] = [value]
		var reader := _load(data)
		assert_true("\n".join(reader.errors).contains("every place must be an object"))


func test_coordinate_lists_reject_bad_types_fractions_and_lengths() -> void:
	for key: String in ["origin", "player_spawn"]:
		for value: Variant in [null, {}, [], ["x", 0], [0.5, 0], [0, 0, "floor"], [0, INF, 0]]:
			var data := _district()
			data[key] = value
			var reader := _load(data)
			assert_false(reader.errors.is_empty(), "invalid " + key)
	for rect: Variant in [["x", 0, 3, 3], [0, [], 3, 3], [0, 0, 3.5, 3], [0, 0, 3], 17]:
		var data := _district()
		data["places"][0]["rect"] = rect
		assert_false(_load(data).errors.is_empty(), "invalid place rect")


func test_level_mappings_reject_bad_keys_and_non_string_filenames() -> void:
	for levels: Variant in [null, [], {}, {"floor": "level_0.txt"}, {"0": []}, {"0": 17}, {"99999999999999999999999": "level_0.txt"}]:
		var data := _district()
		data["levels"] = levels
		assert_false(_load(data).errors.is_empty(), "bad levels")


func test_wrong_district_roots_are_reported() -> void:
	for value: Variant in [null, 17, [], "district"]:
		assert_false(_load(value).errors.is_empty())


func test_valid_district_coordinates_still_load_unchanged() -> void:
	var reader := _load(_district())
	assert_true(reader.errors.is_empty(), "\n".join(reader.errors))


func test_object_coordinates_and_rotation_reject_fractional_values() -> void:
	for placement: Dictionary in [{"def": "fridge", "cell": [1.5, 1, 0], "rotation": 0}, {"def": "fridge", "cell": [1, 1, 0], "rotation": 0.5}]:
		_write("objects.json", Ser.to_json({"objects": [placement]}))
		var reader := _load(_district())
		assert_false(reader.errors.is_empty())


func test_closed_days_need_hours_and_known_day_names() -> void:
	var public := _district()
	public["places"][0]["kind"] = "public"
	public["places"][0].erase("rent")
	public["places"][0]["closed"] = ["sun"]
	assert_true("\n".join(_load(public).errors).contains("\"closed\" only applies to access \"hours\""))
	var shop := _district()
	shop["places"][0]["kind"] = "shop"
	shop["places"][0].erase("rent")  # only homes have rent (T-0062)
	shop["places"][0]["hours"] = [8, 18]
	shop["places"][0]["closed"] = ["sun", "funday"]
	var all := "\n".join(_load(shop).errors)
	assert_true(all.contains("unknown day 'funday'"), all)
	shop["places"][0]["closed"] = ["sat", "sun"]
	assert_true(_load(shop).errors.is_empty())


func test_homes_need_rent_and_only_homes_have_it() -> void:
	var data := _district()
	data["places"][0].erase("rent")
	assert_true("\n".join(_load(data).errors).contains("'rent'"), "a home without rent is reported")
	var shop := _district()
	shop["places"][0]["kind"] = "public"
	assert_true("\n".join(_load(shop).errors).contains("only homes have \"rent\""))
