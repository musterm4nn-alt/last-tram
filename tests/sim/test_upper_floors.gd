extends TestCase
## T-0031: flats on the upper floors, reachable by stairs, each furnished.

const ALTMARKT: Vector3i = Vector3i(30, 30, 0)
const REQUIRED: PackedStringArray = ["bed_double", "fridge", "stove", "sink", "shower", "sofa", "desk", "tv"]
const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"
## The doors of the shops on the ground floor (front and back).
const SHOP_DOORS: Array[Vector3i] = [
	Vector3i(25, 15, 0), Vector3i(36, 15, 0), Vector3i(50, 15, 0),
	Vector3i(5, 23, 0), Vector3i(13, 23, 0), Vector3i(5, 30, 0), Vector3i(13, 30, 0),
]


static func _homes() -> Array[PlaceDef]:
	var out: Array[PlaceDef] = []
	for place: PlaceDef in content().districts["altstadt"].places:
		if place.kind == "home" and place.id != SimFactory.PLAYER_HOME_PLACE:
			out.append(place)
	return out


static func _cells(place: PlaceDef) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y: int in range(place.rect.position.y, place.rect.end.y):
		for x: int in range(place.rect.position.x, place.rect.end.x):
			var cell := Vector3i(x, y, place.level)
			if content().place_at(cell) == place:
				out.append(cell)
	return out


func test_altstadt_has_three_floors_and_fifteen_neighbour_homes() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	assert_eq(content().districts["altstadt"].levels.keys(), [0, 1, 2])
	var homes := _homes()
	assert_eq(homes.size(), 15)
	var upstairs := 0
	for place: PlaceDef in homes:
		if place.level > 0:
			upstairs += 1
	assert_eq(upstairs, 14)


func test_every_home_and_stairwell_is_reachable_from_the_altmarkt() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for place: PlaceDef in content().districts["altstadt"].places:
		if place.kind != "home" and place.kind != "hallway":
			continue
		var reachable := false
		for cell: Vector3i in _cells(place):
			if sim.world.grid.is_walkable(cell) and sim.nav.is_reachable(ALTMARKT, cell):
				reachable = true
				break
		assert_true(reachable, "%s can be reached" % place.id)


func test_every_new_flat_has_its_furniture_with_a_reachable_free_slot() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for place: PlaceDef in _homes():
		var found: Dictionary = {}
		for id: int in sim.world.objects:
			var obj: WorldObject = sim.world.objects[id]
			if content().place_at(obj.origin) != place:
				continue
			for index: int in obj.slot_count(content()):
				var slot := obj.slot_cell(content(), index)
				if sim.world.grid.is_walkable(slot) and sim.nav.is_reachable(ALTMARKT, slot):
					found[obj.def_id] = true
		for def_id: String in REQUIRED:
			assert_true(found.has(def_id), "%s has a usable %s" % [place.id, def_id])


func test_the_shops_keep_their_doors() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for door: Vector3i in SHOP_DOORS:
		assert_eq(sim.world.grid.terrain_def_at(door).id, "door", "door at %s" % door)


func test_the_stairs_link_all_three_floors_in_every_building() -> void:
	var sim := SimFactory.new_game(content(), 1)
	for cell: Vector2i in [Vector2i(29, 13), Vector2i(55, 13), Vector2i(63, 13), Vector2i(10, 28)]:
		assert_true(sim.nav.is_stair_link(Vector3i(cell.x, cell.y, 0), Vector3i(cell.x, cell.y, 1)), "%s 0-1" % cell)
		assert_true(sim.nav.is_stair_link(Vector3i(cell.x, cell.y, 1), Vector3i(cell.x, cell.y, 2)), "%s 1-2" % cell)


func test_an_older_save_gets_lots_for_every_place() -> void:
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	assert_true(sim != null)
	# Save it as a game from before T-0031: keep only the lots of the original places.
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	var kept: Array = []
	for lot: Variant in data["world"]["lots"]:
		var place_id := String((lot as Dictionary)["place_id"])
		if not place_id.begins_with("haus_") or place_id == "haus_3":
			kept.append(lot)
	assert_true(kept.size() < (data["world"]["lots"] as Array).size())
	data["world"]["lots"] = kept
	var loaded := SaveCodec.from_json(JSON.stringify(data), content())
	assert_true(loaded != null)
	for place: PlaceDef in content().districts["altstadt"].places:
		assert_true(Lots.by_place(loaded.world, place.id) != null, "lot for %s" % place.id)
	assert_eq(loaded.world.lots.size(), content().districts["altstadt"].places.size())
