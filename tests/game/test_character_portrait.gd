extends TestCase
## T-0027: the portrait's hair never covers the face, colours follow the look, and the look
## gallery shows every option.


func test_front_hair_never_covers_the_face() -> void:
	for area: Vector2 in [Vector2(200, 240), Vector2(72, 86), Vector2(160, 190)]:
		var head := CharacterPortrait.head_rect(area)
		var face := CharacterPortrait.face_rect(head)
		for style: String in content().appearance.hair_styles:
			var shape := str(ViewConfig.HAIR_SHAPE.get(style, "cap"))
			for rect: Rect2 in CharacterPortrait.hair_front_rects(shape, head):
				assert_false(rect.intersects(face), "%s (%s) covers the face at %s" % [style, shape, area])


func test_every_hair_shape_is_known() -> void:
	for style: String in content().appearance.hair_styles:
		assert_true(ViewConfig.HAIR_SHAPE.has(style), "%s has no hair shape" % style)
	var head := CharacterPortrait.head_rect(Vector2(200, 240))
	assert_true(CharacterPortrait.hair_front_rects("none", head).is_empty(), "bald shows no hair")
	assert_false(CharacterPortrait.hair_front_rects("afro", head).is_empty())


func test_colours_follow_the_look() -> void:
	var db := content()
	assert_ne(PersonDrawer2D.hair_color(db, "black"), PersonDrawer2D.hair_color(db, "ginger"))
	assert_ne(PersonDrawer2D.skin_color(db, "skin_01"), PersonDrawer2D.skin_color(db, "skin_08"))
	assert_ne(PersonDrawer2D.eye_color(db, "blue"), PersonDrawer2D.eye_color(db, "brown"))
	assert_eq(PersonDrawer2D.eye_color(db, "no_such_eye"), ViewConfig.UNKNOWN_ID_COLOR)


func test_the_gallery_covers_every_option() -> void:
	var db := content()
	var catalog := db.appearance
	var looks := LookGallery.entries(db, 1)
	var expected := catalog.hair_styles.size() + catalog.builds.size() + catalog.facial_hair.size() \
		+ catalog.features.size() + 1 + catalog.skin_tones.size()
	assert_eq(looks.size(), expected)
	var starters := 0
	for item: ClothingDef in db.clothing.values():
		if item.starter:
			starters += 1
	assert_eq(LookGallery.entries(db, 2).size(), starters)
	for entry: Dictionary in looks + LookGallery.entries(db, 2):
		assert_eq((entry["spec"] as CharacterSpec).validate(db), PackedStringArray(), String(entry["label"]))
