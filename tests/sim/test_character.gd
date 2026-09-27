extends TestCase
## T-0018: every person has identity, appearance and outfit; CharacterSpec describes,
## validates and creates characters; v1 saves migrate to v2.


func test_default_player_spec_is_valid() -> void:
	var problems := CharacterSpec.default_player(content()).validate(content())
	assert_true(problems.is_empty(), "default player is invalid: %s" % [problems])


func test_new_game_player_matches_default_spec() -> void:
	var db := content()
	var spec := CharacterSpec.default_player(db)
	var player := SimFactory.new_game(db, 1).world.player()
	assert_eq(player.first_name, spec.first_name)
	assert_eq(player.last_name, spec.last_name)
	assert_eq(player.nickname, spec.nickname)
	assert_eq(player.gender, spec.gender)
	assert_eq(player.pronouns, spec.pronouns)
	assert_eq(player.age_years, spec.age_years)
	assert_eq(player.display_name(), spec.first_name)
	assert_eq(player.appearance.to_dict(), spec.appearance.to_dict())
	assert_eq(player.outfit.to_dict(), spec.outfit.to_dict())


func test_new_game_with_custom_spec() -> void:
	var db := content()
	var spec := CharacterSpec.default_player(db)
	spec.first_name = "Eva"
	spec.last_name = "Horvat"
	spec.nickname = "Evie"
	spec.age_years = 35
	spec.appearance.height_cm = 180
	spec.appearance.hair_style = "bob"
	assert_true(spec.validate(db).is_empty(), "custom spec should be valid")
	var player := SimFactory.new_game(db, 42, spec).world.player()
	assert_eq(player.first_name, "Eva")
	assert_eq(player.last_name, "Horvat")
	assert_eq(player.nickname, "Evie")
	assert_eq(player.display_name(), "Evie")
	assert_eq(player.age_years, 35)
	assert_eq(player.appearance.to_dict(), spec.appearance.to_dict())
	assert_eq(player.outfit.to_dict(), spec.outfit.to_dict())


func test_random_specs_are_valid_and_deterministic() -> void:
	var db := content()
	for seed_value: int in range(1, 201):
		var spec := _random_spec(seed_value)
		var problems := spec.validate(db)
		assert_true(problems.is_empty(), "seed %d is invalid: %s" % [seed_value, problems])
	var a := _random_spec(7)
	var b := _random_spec(7)
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()))


func test_validate_rejects_bad_identity() -> void:
	var db := content()
	var aged := CharacterSpec.default_player(db)
	aged.age_years = 17
	assert_false(aged.validate(db).is_empty(), "age 17 must be rejected")
	var nameless := CharacterSpec.default_player(db)
	nameless.first_name = ""
	assert_false(nameless.validate(db).is_empty(), "empty first name must be rejected")
	var digits := CharacterSpec.default_player(db)
	digits.first_name = "Al3x"
	assert_false(digits.validate(db).is_empty(), "a name with digits must be rejected")
	var long_name := CharacterSpec.default_player(db)
	long_name.first_name = "abcdefghijklmnopqrstuvwxyz".substr(0, 25)
	assert_false(long_name.validate(db).is_empty(), "a 25-letter name must be rejected")


func test_validate_rejects_bad_appearance() -> void:
	var db := content()
	var skin := CharacterSpec.default_player(db)
	skin.appearance.skin_tone = "no_such_skin"
	assert_false(skin.validate(db).is_empty(), "unknown skin tone must be rejected")
	var hair_colour := CharacterSpec.default_player(db)
	hair_colour.appearance.hair_colour = "no_such_colour"
	assert_false(hair_colour.validate(db).is_empty(), "unknown hair colour must be rejected")
	var hair_style := CharacterSpec.default_player(db)
	hair_style.appearance.hair_style = "no_such_style"
	assert_false(hair_style.validate(db).is_empty(), "unknown hair style must be rejected")


func test_validate_rejects_bad_outfit() -> void:
	var db := content()
	var wrong_slot := CharacterSpec.default_player(db)
	wrong_slot.outfit.take_off("top")
	wrong_slot.outfit.put_on("top", "jeans", "denim")
	assert_false(wrong_slot.validate(db).is_empty(), "an item in the wrong slot must be rejected")
	var bad_colour := CharacterSpec.default_player(db)
	bad_colour.outfit.put_on("top", "t_shirt", "no_such_colour")
	assert_false(bad_colour.validate(db).is_empty(), "a colour the item does not allow must be rejected")
	for slot: String in ["top", "bottom", "feet"]:
		var missing := CharacterSpec.default_player(db)
		missing.outfit.take_off(slot)
		assert_false(missing.validate(db).is_empty(), "a missing %s must be rejected" % slot)


func test_apply_to_deep_copies() -> void:
	var spec := CharacterSpec.default_player(content())
	var person := Person.new()
	spec.apply_to(person)
	spec.outfit.get_item("top").colour = "changed"
	spec.outfit.put_on("bottom", "t_shirt", "black")
	spec.appearance.skin_tone = "changed"
	assert_eq(person.outfit.get_item("top").colour, "black")
	assert_eq(person.outfit.get_item("bottom").clothing_id, "jeans")
	assert_eq(person.appearance.skin_tone, "skin_04")


func test_identity_appearance_and_outfit_survive_save_load() -> void:
	var db := content()
	# Not the default player: values that differ from Person's defaults prove every field is saved.
	var spec := _random_spec(3)
	spec.nickname = "Mo"
	spec.age_years = 44
	var sim := SimFactory.new_game(db, 7, spec)
	sim.run_minutes(30)
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), db, errors)
	assert_true(loaded != null, "load failed: %s" % [errors])
	if loaded == null:
		return
	assert_eq(SaveCodec.to_json(loaded), SaveCodec.to_json(sim))
	var before := sim.world.player()
	var after := loaded.world.player()
	assert_eq(before.nickname, "Mo")
	assert_eq(after.first_name, spec.first_name)
	assert_eq(after.last_name, spec.last_name)
	assert_eq(after.nickname, "Mo")
	assert_eq(after.gender, spec.gender)
	assert_eq(after.pronouns, spec.pronouns)
	assert_eq(after.age_years, 44)
	assert_eq(after.appearance.to_dict(), spec.appearance.to_dict())
	assert_eq(after.outfit.to_dict(), spec.outfit.to_dict())


func test_v1_fixture_migrates_to_valid_character() -> void:
	var db := content()
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v1_basic.json"), db, errors)
	assert_true(sim != null, "v1 fixture does not load: %s" % [errors])
	if sim == null:
		return
	var player := sim.world.player()
	assert_eq(player.nickname, "")
	assert_eq(player.gender, "nonbinary")
	assert_eq(player.pronouns, "they")
	assert_eq(player.age_years, 27)
	assert_true(player.appearance.validate(db).is_empty(), "migrated appearance is invalid")
	assert_true(player.outfit.validate(db).is_empty(), "migrated outfit is invalid")


func test_v2_fixture_loads() -> void:
	var errors: Array[String] = []
	var sim := SaveCodec.from_json(FileAccess.get_file_as_string("res://tests/fixtures/saves/v2_basic.json"), content(), errors)
	assert_true(sim != null, "v2 fixture does not load: %s" % [errors])
	if sim != null:
		assert_eq(SaveCodec.to_dict(sim)["save_version"], SaveCodec.SAVE_VERSION)


func _random_spec(seed_value: int) -> CharacterSpec:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return CharacterSpec.random(content(), rng)
