extends TestCase
## T-0080: art sets map terrain and objects to sheet regions, drop bad entries with an error
## (so they fall back to placeholders), and pick terrain variants by a stable hash.

const ROOT: String = "res://tests/fixtures/art2d"


func test_loads_fixture_set() -> void:
	var art := ArtSet.load_set("fixture", content(), ROOT)
	assert_eq(art.errors, [] as Array[String])
	assert_eq(art.id, "fixture")
	assert_eq(art.name, "Test fixture")
	var road := art.terrain_tile("road", Vector2i(5, 7))
	assert_eq(road["region"], Rect2i(48, 0, 16, 16))
	assert_true(road["texture"] is Texture2D)
	var grass_region: Rect2i = art.terrain_tile("grass", Vector2i(2, 3))["region"]
	assert_eq(grass_region.position.y, 0)
	assert_eq(grass_region.size, Vector2i(16, 16))
	assert_eq(grass_region.position.x, ArtSet.variant_index(Vector2i(2, 3), 3) * 16)
	for rotation: int in 4:
		assert_eq(art.object_sprite("bench", rotation)["region"], Rect2i(0, 16, 16, 24), "one rect for every rotation")
	assert_eq(art.object_sprite("bed_double", 0)["region"], Rect2i(16, 16, 32, 48))
	assert_eq(art.object_sprite("bed_double", 1)["region"], Rect2i(48, 16, 48, 32))
	assert_eq(art.object_sprite("bed_double", 3)["region"], Rect2i(128, 16, 48, 32))
	assert_eq(art.terrain_tile("wall", Vector2i.ZERO), {}, "unmapped terrain")
	assert_eq(art.object_sprite("fridge", 0), {}, "unmapped object")


func test_bad_entries_fall_back() -> void:
	var art := ArtSet.load_set("bad", content(), ROOT)
	var text := "\n".join(art.errors)
	for expected: String in ["sheet 'gone': file not found", "terrain 'lava': no such terrain",
			"terrain 'road': no loaded sheet 'gone'", "terrain 'grass': cell", "object 'spaceship': no such object",
			"object 'bench': rect", "object 'sofa': 'rects' must list 4"]:
		assert_true(text.contains(expected), "expected an error containing \"%s\" in:\n%s" % [expected, text])
	assert_eq(art.errors.size(), 9, text)
	for terrain_id: String in ["lava", "road", "grass"]:
		assert_eq(art.terrain_tile(terrain_id, Vector2i.ZERO), {}, "%s falls back" % terrain_id)
	for def_id: String in ["spaceship", "bench", "sofa"]:
		assert_eq(art.object_sprite(def_id, 0), {}, "%s falls back" % def_id)
	assert_false(art.terrain_tile("sidewalk", Vector2i.ZERO).is_empty(), "good entries still load")
	assert_false(art.object_sprite("tv", 0).is_empty(), "good entries still load")


func test_missing_set() -> void:
	var art := ArtSet.load_set("no_such_set", content(), ROOT)
	assert_eq(art.errors.size(), 1)
	assert_true(art.errors[0].contains("file not found"), art.errors[0])
	assert_eq(art.terrain_tile("grass", Vector2i.ZERO), {})
	assert_eq(ArtSet.new().object_sprite("bench", 0), {}, "the empty set maps nothing")


func test_variant_index_is_stable() -> void:
	var counts: Array[int] = [0, 0, 0, 0]
	for y: int in 20:
		for x: int in 20:
			var index := ArtSet.variant_index(Vector2i(x, y), 4)
			assert_eq(index, ArtSet.variant_index(Vector2i(x, y), 4))
			counts[index] += 1
	for n: int in counts:
		assert_true(n > 60, "every variant is used often: %s" % [counts])
	assert_eq(ArtSet.variant_index(Vector2i(9, 4), 1), 0)
	assert_eq(ArtSet.variant_index(Vector2i(-3, 8), 4), ArtSet.variant_index(Vector2i(-3, 8), 4))
	assert_true(ArtSet.variant_index(Vector2i(-3, -8), 4) >= 0)


func test_sprite_rect_anchors_to_footprint() -> void:
	var footprint := Rect2(32, 48, 32, 16)  # a 2x1 bench at cells (2,3)-(3,3)
	assert_eq(ObjectView2D.sprite_rect(footprint, Vector2i(32, 16)), Rect2(32, 48, 32, 16), "same size: same place")
	assert_eq(ObjectView2D.sprite_rect(footprint, Vector2i(32, 40)), Rect2(32, 24, 32, 40), "taller: rises above")
	assert_eq(ObjectView2D.sprite_rect(footprint, Vector2i(20, 16)), Rect2(38, 48, 20, 16), "narrower: centred")
	assert_eq(ObjectView2D.sprite_rect(footprint, Vector2i(21, 16)), Rect2(37, 48, 21, 16), "whole pixels")


## T-0085
func test_thin_wall_colours() -> void:
	var art := ArtSet.load_set("fixture", content(), ROOT)
	assert_eq(art.thin_walls.size(), 2)
	assert_eq(art.thin_walls["top"], Color("#d8c3a5"))
	var bad := ArtSet.load_set("bad", content(), ROOT)
	assert_true("\n".join(bad.errors).contains("thin_walls 'roof': unknown colour"), "\n".join(bad.errors))
	assert_true("\n".join(bad.errors).contains("thin_walls 'edge': must be a colour"), "\n".join(bad.errors))
