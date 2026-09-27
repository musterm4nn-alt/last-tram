extends TestCase
## T-0017: appearance, clothing and name catalogs load from data/ and are validated.

const BROKEN_CONTENT: String = "res://tests/fixtures/content_broken"


func test_minimum_creator_choices_exist() -> void:
	var catalog: AppearanceCatalog = content().appearance
	assert_true(catalog.genders.size() >= 3, "at least 3 genders")
	assert_true(catalog.pronouns.size() >= 3, "at least 3 pronoun sets")
	assert_true(catalog.skin_tones.size() >= 8, "at least 8 skin tones")
	assert_true(catalog.hair_colours.size() >= 15, "at least 15 hair colours")
	assert_true(catalog.eye_colours.size() >= 6, "at least 6 eye colours")
	assert_true(catalog.hair_styles.size() >= 15, "at least 15 hair styles")
	assert_true(catalog.builds.size() >= 5, "at least 5 builds")
	assert_true(catalog.facial_hair.size() >= 6, "at least 6 facial hair options")
	assert_true(catalog.features.size() >= 3, "at least 3 features")
	assert_true(catalog.age_min >= 18, "everyone in the game is an adult")
	assert_true(catalog.age_max >= catalog.age_min, "age max must not be below min")
	assert_true(catalog.height_min >= 120 and catalog.height_min < catalog.height_max and catalog.height_max <= 230, "heights must satisfy 120 <= min < max <= 230")


func test_hair_colours_are_natural_and_dyed() -> void:
	var catalog: AppearanceCatalog = content().appearance
	var natural := 0
	var dyed := 0
	for option: ColorOption in catalog.hair_colours.values():
		if option.natural:
			natural += 1
		else:
			dyed += 1
	assert_true(natural >= 9, "at least 9 natural hair colours")
	assert_true(dyed >= 6, "at least 6 dyed hair colours")


func test_name_lists_have_minimum_names() -> void:
	var db := content()
	var minimums: Dictionary[String, int] = { "feminine": 30, "masculine": 30, "neutral": 12 }
	for list_id: String in minimums:
		assert_true(db.first_names.has(list_id), "first_names must have a '%s' list" % list_id)
		if db.first_names.has(list_id):
			assert_true(db.first_names[list_id].size() >= minimums[list_id], "'%s' needs at least %d names" % [list_id, minimums[list_id]])
	assert_true(db.last_names.size() >= 50, "at least 50 last names")


func test_all_content_names_are_valid() -> void:
	var db := content()
	for list_id: String in db.first_names:
		for name: String in db.first_names[list_id]:
			assert_true(Names.is_valid(name), "'%s' in '%s' must be a valid name" % [name, list_id])
	for name: String in db.last_names:
		assert_true(Names.is_valid(name), "'%s' must be a valid name" % name)


func test_every_gender_has_pronouns_and_name_lists() -> void:
	var db := content()
	assert_true(db.appearance.genders.size() > 0, "at least one gender")
	for gender: GenderOption in db.appearance.genders.values():
		assert_true(db.appearance.pronouns.has(gender.default_pronouns), "gender '%s' uses unknown pronouns '%s'" % [gender.id, gender.default_pronouns])
		assert_true(gender.name_lists.size() > 0, "gender '%s' has no name lists" % gender.id)
		for list_id: String in gender.name_lists:
			assert_true(db.first_names.has(list_id), "gender '%s' uses unknown name list '%s'" % [gender.id, list_id])


func test_every_required_slot_has_a_starter_item() -> void:
	var db := content()
	for slot: String in ClothingDef.REQUIRED_SLOTS:
		var found := false
		for item: ClothingDef in db.clothing.values():
			if item.slot == slot and item.starter:
				found = true
				break
		assert_true(found, "no starter item in required slot '%s'" % slot)


func test_items_have_valid_slots_colours_and_ranges() -> void:
	var db := content()
	assert_true(db.clothing.size() >= 22, "at least 22 starter clothing items")
	for item: ClothingDef in db.clothing.values():
		assert_true(ClothingDef.SLOTS.has(item.slot), "item '%s' has invalid slot '%s'" % [item.id, item.slot])
		assert_true(item.colours.size() > 0, "item '%s' has no colours" % item.id)
		for colour_id: String in item.colours:
			assert_true(db.clothing_colours.has(colour_id), "item '%s' uses unknown colour '%s'" % [item.id, colour_id])
		assert_true(item.price >= 0, "item '%s' has a negative price" % item.id)
		assert_true(item.formality >= -2 and item.formality <= 3, "item '%s' formality must be -2..3" % item.id)
		assert_true(item.concealment >= 0 and item.concealment <= 3, "item '%s' concealment must be 0..3" % item.id)
		assert_true(item.warmth >= 0 and item.warmth <= 3, "item '%s' warmth must be 0..3" % item.id)


func test_default_character_clothes_are_allowed() -> void:
	var db := content()
	var wanted: Dictionary[String, String] = { "t_shirt": "black", "jeans": "denim", "trainers": "white", "hoodie": "grey" }
	for item_id: String in wanted:
		var item := db.clothing_def(item_id)
		assert_true(item != null, "T-0018's default character needs a '%s'" % item_id)
		if item != null:
			assert_true(item.colours.has(wanted[item_id]), "'%s' must come in '%s'" % [item_id, wanted[item_id]])


func test_clothing_def_returns_null_for_unknown_ids() -> void:
	var db := content()
	assert_true(db.clothing_def("cape") == null, "unknown clothing ids must give null")
	assert_true(db.clothing_def("") == null)


func test_names_is_valid_accepts_real_names() -> void:
	for name: String in ["Jürgen", "Łukasz", "Anne-Marie", "O'Neill", "Nguyễn"]:
		assert_true(Names.is_valid(name), "'%s' should be a valid name" % name)


func test_names_is_valid_rejects_bad_names() -> void:
	var too_long := "Abcdefghijklmnopqrstuvwxy"
	assert_eq(too_long.length(), 25)
	for name: String in ["", " Anna", "R2D2", "Anna!", too_long]:
		assert_false(Names.is_valid(name), "'%s' should be rejected" % name)


func test_names_is_valid_respects_max_length() -> void:
	assert_true(Names.is_valid("Anne", 4), "a 4-letter name fits max_length 4")
	assert_false(Names.is_valid("Anne", 3), "a 4-letter name does not fit max_length 3")


func test_broken_appearance_content_is_reported() -> void:
	var db := ContentDB.new()
	db.load_from(BROKEN_CONTENT)
	var all := "\n".join(db.errors)
	assert_false(db.is_valid())
	assert_true(all.contains("at least 18"), "age below 18 must be reported: " + all)
	assert_true(all.contains("unknown colour 'neon_green'"), "unknown clothing colour must be reported: " + all)
	assert_true(all.contains("slot 'hat'"), "invalid clothing slot must be reported: " + all)
	assert_true(all.contains("duplicate clothing id"), "duplicate clothing id must be reported: " + all)
	assert_true(all.contains("no starter item in required slot 'bottom'"), "missing starter item must be reported: " + all)
