extends TestCase
## T-0090: the default player's sprite imports with complete animations, keeps its feet
## aligned, and uses only the existing custom art palette. Visual quality is reviewed in PNG/GIF.

const ASSET_ROOT: String = "res://art/export/custom/characters/alex_novak"


func test_all_directions_keep_idle_and_walk_timing() -> void:
	var frames: SpriteFrames = load(ASSET_ROOT + ".tres")
	assert_true(frames != null, "Godot must import the SpriteFrames resource")
	if frames == null:
		return
	assert_eq(frames.get_animation_names().size(), 8)
	for direction: String in ["down", "up", "left", "right"]:
		for action: String in ["idle", "walk"]:
			var name := StringName(action + "_" + direction)
			assert_true(frames.has_animation(name), str(name))
			if not frames.has_animation(name):
				continue
			assert_true(frames.get_animation_loop(name), str(name) + " loops")
			var count: int = 2 if action == "idle" else 4
			assert_eq(frames.get_frame_count(name), count, str(name))
			for i: int in count:
				var seconds: float = frames.get_frame_duration(name, i) / frames.get_animation_speed(name)
				var expected: float = 0.12 if action == "walk" else (1.85 if i == 0 else 0.15)
				assert_true(absf(seconds - expected) < 0.00001, "%s frame %d preserves timing" % [name, i])


func test_atlas_preserves_canvas_and_transparent_feet_origin() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT + ".json"))
	var slice: Dictionary = metadata["meta"]["slices"][0]
	assert_eq(str(slice["name"]), "feet_origin")
	var key: Dictionary = slice["keys"][0]
	assert_true(key.has("pivot"), "exported metadata retains the source feet pivot")
	if key.has("pivot"):
		assert_eq(int(key["pivot"]["x"]), 8)
		assert_eq(int(key["pivot"]["y"]), 31)
	var frames: SpriteFrames = load(ASSET_ROOT + ".tres")
	for name: StringName in frames.get_animation_names():
		for i: int in frames.get_frame_count(name):
			var atlas: AtlasTexture = frames.get_frame_texture(name, i) as AtlasTexture
			assert_true(atlas != null, "each animation uses an atlas region")
			if atlas == null:
				continue
			assert_eq(atlas.region.size, Vector2(16, 32), "no trimming may shift Alex's feet")
			var image: Image = atlas.atlas.get_image()
			var sheet_rect := Rect2(Vector2.ZERO, Vector2(image.get_size()))
			assert_true(sheet_rect.encloses(atlas.region), "region stays inside the sheet")
			var origin := Vector2i(atlas.region.position)
			var planted: bool = false
			for x: int in 16:
				assert_eq(image.get_pixel(origin.x + x, origin.y + 31).a, 0.0, "bottom row remains transparent")
				planted = planted or image.get_pixel(origin.x + x, origin.y + 30).a == 1.0
			assert_true(planted, "at least one shoe stays on the ground in every pose")
			assert_eq(image.get_pixel(origin.x, origin.y).a, 0.0, "canvas corner stays transparent")


func test_opaque_pixels_use_only_the_existing_custom_palette() -> void:
	var source := FileAccess.get_file_as_string("res://art/src/custom/draw_custom.lua")
	var regex := RegEx.new()
	regex.compile("#[0-9a-fA-F]{6}")
	var allowed: Dictionary[String, bool] = {}
	for found: RegExMatch in regex.search_all(source):
		allowed[found.get_string().trim_prefix("#").to_lower()] = true
	var sheet: Texture2D = load(ASSET_ROOT + ".png")
	var image: Image = sheet.get_image()
	var used: Dictionary[String, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			var colour := image.get_pixel(x, y)
			assert_true(colour.a == 0.0 or colour.a == 1.0, "no antialiasing or semitransparent sprite pixels")
			if colour.a == 0.0:
				continue
			var key := colour.to_html(false)
			used[key] = true
			assert_true(allowed.has(key), "colour #%s belongs to route B" % key)
	assert_true(used.size() <= 20, "small deliberate palette")
	assert_true(used.size() >= 8, "the exported sheet contains the shaded artwork")
