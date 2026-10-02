extends TestCase
## T-0021: the character creator's model. Every option list, the limits, features, the
## starter outfit, and randomising one section without touching the others.


## CreatorModel.randomise_all(seed) before the personality section existed.
const RANDOMISE_ALL_GOLDEN: Dictionary = {
	77: '{"age_years":56,"appearance":{"build":"slim","eye_colour":"green","facial_hair":"none","features":[],"hair_colour":"blonde","hair_style":"ponytail","height_cm":179,"skin_tone":"skin_07"},"first_name":"Anna","gender":"nonbinary","last_name":"Schmidt","nickname":"","outfit":{"bottom":{"colour":"navy","item":"skirt"},"feet":{"colour":"black","item":"boots"},"neck":{"colour":"mustard","item":"chain"},"outer":{"colour":"navy","item":"blazer"},"top":{"colour":"pink","item":"blouse"}},"pronouns":"she"}',
	5: '{"age_years":65,"appearance":{"build":"average","eye_colour":"green","facial_hair":"none","features":[],"hair_colour":"purple","hair_style":"afro","height_cm":201,"skin_tone":"skin_07"},"first_name":"Matthias","gender":"woman","last_name":"Khoury","nickname":"","outfit":{"bottom":{"colour":"burgundy","item":"skirt"},"face":{"colour":"brown","item":"sunglasses"},"feet":{"colour":"brown","item":"boots"},"hands":{"colour":"brown","item":"gloves"},"top":{"colour":"navy","item":"t_shirt"}},"pronouns":"she"}',
}


func _model() -> CreatorModel:
	return CreatorModel.new(content())


## Each section's fields as text, to compare before and after.
func _sections(model: CreatorModel) -> Dictionary:
	var s := model.spec
	var look := s.appearance
	return {
		"name": "%s|%s|%s" % [s.first_name, s.last_name, s.nickname],
		"identity": "%s|%s|%d" % [s.gender, s.pronouns, s.age_years],
		"body": "%d|%s|%s" % [look.height_cm, look.build, look.skin_tone],
		"face": "%s|%s|%s|%s|%s" % [look.hair_style, look.hair_colour, look.eye_colour, look.facial_hair, ",".join(look.features)],
		"clothes": Ser.to_json(s.outfit.to_dict()),
		"personality": Ser.to_json(s.personality.to_dict()),
	}


func test_a_new_model_has_no_name_and_the_default_look() -> void:
	var model := _model()
	assert_eq(model.spec.first_name, "")
	assert_eq(model.spec.last_name, "")
	var default_look := CharacterSpec.default_player(content())
	assert_eq(model.spec.appearance.to_dict(), default_look.appearance.to_dict())
	assert_eq(model.spec.outfit.to_dict(), default_look.outfit.to_dict())
	var problems := model.errors()
	assert_eq(problems.size(), 2, "%s" % [problems])
	for problem: String in problems:
		assert_true(problem.begins_with("first name") or problem.begins_with("last name"), problem)


func test_every_list_steps_through_every_option_and_wraps() -> void:
	var model := _model()
	for field: String in CreatorModel.LIST_FIELDS:
		var ids := model.options(field)
		assert_true(ids.size() >= 2, "%s should offer choices" % field)
		var start := model.value(field)
		var seen: Dictionary = {}
		for i: int in ids.size():
			model.next(field)
			seen[model.value(field)] = true
		assert_eq(seen.size(), ids.size(), "%s: next() should visit every option once" % field)
		assert_eq(model.value(field), start, "%s: a full round comes back to the start" % field)
		while model.value(field) != ids[0]:
			model.next(field)
		model.previous(field)
		assert_eq(model.value(field), ids[ids.size() - 1], "%s: previous() from the first goes to the last" % field)


func test_gender_and_pronouns_are_independent() -> void:
	var model := _model()
	var pronouns := model.value("pronouns")
	model.next("gender")
	assert_eq(model.value("pronouns"), pronouns)


func test_age_and_height_stay_within_the_creators_limits() -> void:
	var model := _model()
	model.set_age(17)
	assert_eq(model.spec.age_years, 18)
	model.set_age(81)
	assert_eq(model.spec.age_years, 80)
	model.set_age(40)
	assert_eq(model.spec.age_years, 40)
	model.set_age(-5)
	assert_eq(model.spec.age_years, 18, "never below 18")
	model.set_height(140)
	assert_eq(model.spec.appearance.height_cm, 150)
	model.set_height(210)
	assert_eq(model.spec.appearance.height_cm, 205)


func test_features_toggle_and_keep_catalog_order() -> void:
	var model := _model()
	var ids := model.feature_options()
	assert_true(ids.size() >= 2)
	model.toggle_feature(ids[1])
	model.toggle_feature(ids[0])
	assert_eq(model.spec.appearance.features, PackedStringArray([ids[0], ids[1]]))
	model.toggle_feature(ids[0])
	assert_eq(model.spec.appearance.features, PackedStringArray([ids[1]]))


func test_clothes_cycle_through_starter_items_with_their_colours() -> void:
	var model := _model()
	for slot: String in ClothingDef.REQUIRED_SLOTS:
		assert_false(model.clothing_options(slot).has(""), "%s is required: no 'nothing'" % slot)
	assert_true(model.clothing_options("head").has(""), "optional slots can be empty")
	var bottoms := model.clothing_options("bottom")
	var seen: Dictionary = {}
	for i: int in bottoms.size():
		model.next_clothing("bottom")
		seen[model.clothing("bottom")] = true
		var def := content().clothing_def(model.clothing("bottom"))
		assert_eq(model.spec.outfit.get_item("bottom").colour, def.colours[0], "a new item starts in its first colour")
	assert_eq(seen.size(), bottoms.size(), "every starter bottom")
	var before := model.spec.outfit.to_dict()
	model.set_colour("bottom", "no_such_colour")
	assert_eq(model.spec.outfit.to_dict(), before, "a colour the item lacks changes nothing")
	var colours := model.colour_options("bottom")
	model.set_colour("bottom", colours[colours.size() - 1])
	assert_eq(model.spec.outfit.get_item("bottom").colour, colours[colours.size() - 1])


func test_taking_off_an_optional_item() -> void:
	var model := _model()
	while model.clothing("outer") != "":
		model.next_clothing("outer")
	assert_eq(model.spec.outfit.get_item("outer"), null)
	assert_eq(model.colour_options("outer"), PackedStringArray())


func test_randomising_a_section_leaves_the_others_alone() -> void:
	for section: String in CreatorModel.SECTIONS:
		for seed_value: int in 20:
			var model := _model()
			model.spec.first_name = "Mira"
			model.spec.last_name = "Kovač"
			var before := _sections(model)
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			model.randomise(section, rng)
			var after := _sections(model)
			for other: String in CreatorModel.SECTIONS:
				if other != section:
					assert_eq(after[other], before[other], "randomising %s changed %s (seed %d)" % [section, other, seed_value])


func test_random_names_come_from_the_genders_name_lists() -> void:
	var model := _model()
	var gender: GenderOption = content().appearance.genders[model.spec.gender]
	var allowed: Dictionary = {}
	for list_id: String in gender.name_lists:
		for first: String in content().first_names[list_id]:
			allowed[first] = true
	for seed_value: int in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		model.randomise("name", rng)
		assert_true(allowed.has(model.spec.first_name), model.spec.first_name)
		assert_true(content().last_names.has(model.spec.last_name), model.spec.last_name)
		assert_eq(model.spec.nickname, "")


func test_personality_section_randomises_and_sets_traits() -> void:
	var model := _model()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	model.randomise("personality", rng)
	var check := RandomNumberGenerator.new()
	check.seed = 9
	assert_eq(model.spec.personality.to_dict(), Personality.random(check).to_dict())
	model.set_trait("temper", 140)
	model.set_trait("kindness", -35)
	model.set_trait("charm", 50)
	assert_eq(model.spec.personality.get_axis("temper"), 100, "clamped")
	assert_eq(model.spec.personality.get_axis("kindness"), -35)
	assert_false(model.spec.personality.values.has("charm"))


func test_randomise_all_keeps_the_earlier_sections_as_before_personality() -> void:
	# Recorded on main before T-0044 (spec.to_dict() without "personality").
	for seed_value: int in RANDOMISE_ALL_GOLDEN:
		var model := _model()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		model.randomise_all(rng)
		var d := model.spec.to_dict()
		d.erase("personality")
		assert_eq(JSON.stringify(d), RANDOMISE_ALL_GOLDEN[seed_value], "seed %d" % seed_value)


func test_randomise_all_is_repeatable_and_always_valid() -> void:
	var a := _model()
	var b := _model()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 77
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 77
	a.randomise_all(rng_a)
	b.randomise_all(rng_b)
	assert_eq(a.spec.to_dict(), b.spec.to_dict())
	for seed_value: int in 100:
		var model := _model()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		model.randomise_all(rng)
		assert_eq(model.errors(), PackedStringArray(), "seed %d" % seed_value)
		assert_true(model.spec.age_years >= 18 and model.spec.age_years <= 80)
		assert_true(model.spec.appearance.height_cm >= 150 and model.spec.appearance.height_cm <= 205)


func test_wardrobe_model_offers_only_owned_clothes() -> void:
	var model := CreatorModel.new(content(), CharacterSpec.default_player(content()))
	model.owned = [WornItem.new("t_shirt", "black"), WornItem.new("shirt", "white"), WornItem.new("shirt", "navy"),
		WornItem.new("jeans", "denim"), WornItem.new("trainers", "white")] as Array[WornItem]
	model.only_owned = true
	assert_eq(model.clothing_options("top"), PackedStringArray(["t_shirt", "shirt"]))
	assert_eq(model.clothing_options("head"), PackedStringArray([""]), "nothing owned: only 'None'")
	model.spec.outfit.put_on("top", "shirt", "white")
	assert_eq(model.colour_options("top"), PackedStringArray(["white", "navy"]), "the owned colours, in catalog order")
	model.next_clothing("top")
	assert_eq(model.clothing("top"), "t_shirt")
	assert_eq(model.spec.outfit.get_item("top").colour, "black", "an owned colour")
