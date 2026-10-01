extends TestCase
## T-0037: relationships, memories and moodlets.

const ROOM: PackedStringArray = ["######", "#@...#", "######"]
const V3_SAVE: String = "res://tests/fixtures/saves/v3_basic.json"
const DAY: int = SimClock.MINUTES_PER_DAY


func _two() -> Array:
	var sim := SimFactory.from_rows(content(), ROOM)
	var other := SimFactory.spawn_person(sim, Vector3i(3, 1, 0), CharacterSpec.default_player(content()))
	return [sim, sim.world.player(), other]


func test_relationships_are_directed_and_clamped() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	assert_eq(Social.relationship(a, b.id), null, "strangers have no relationship yet")
	Social.change(sim, a, b.id, {"friendship": 150.0, "familiarity": 10.0, "fear": -5.0})
	var r := Social.relationship(a, b.id)
	assert_eq(r.friendship, 100.0)
	assert_eq(r.familiarity, 10.0)
	assert_eq(r.fear, 0.0)
	assert_eq(r.last_contact_tick, sim.clock.tick)
	assert_eq(Social.relationship(b, a.id), null, "b's view is separate")


func test_households_start_out_knowing_each_other() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var couples := 0
	for household: Household in sim.world.households.values():
		if household.member_ids.size() < 2:
			continue
		var a := sim.world.get_person(household.member_ids[0])
		var r := Social.relationship(a, household.member_ids[1])
		assert_true(r != null and r.familiarity >= 70.0, household.kind)
		if household.kind == Household.COUPLE:
			couples += 1
			assert_true(r.romance > 0.0 and Social.relationship(sim.world.get_person(household.member_ids[1]), a.id).romance > 0.0)
		else:
			assert_eq(r.romance, 0.0, "flatmates are not partners")
	assert_true(couples > 0)


func test_without_contact_relationships_drift_towards_neutral() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	Social.change(sim, a, b.id, {"friendship": 40.0, "trust": -20.0, "familiarity": 60.0, "fear": 10.0})
	sim.run_minutes(DAY)
	assert_eq(Social.relationship(a, b.id).friendship, 40.0, "no drift in the first days")
	sim.run_minutes(5 * DAY)
	var r := Social.relationship(a, b.id)
	assert_true(r.friendship < 40.0 and r.friendship > 0.0, "friendship %s" % r.friendship)
	assert_true(r.trust > -20.0 and r.trust < 0.0, "trust %s" % r.trust)
	assert_true(r.familiarity >= Social.FAMILIARITY_FLOOR and r.familiarity < 60.0)
	Social.change(sim, a, b.id, {})
	var before := r.friendship
	sim.run_minutes(DAY)
	assert_eq(r.friendship, before, "contact resets the wait")


func test_memories_are_capped_and_fade() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	for i: int in Social.MEMORY_CAP + 5:
		Social.remember(sim, a, "saw_%d" % i, [b.id] as Array[int], 10, 30.0 + i * 0.5)
	assert_eq(a.memories.size(), Social.MEMORY_CAP)
	assert_false(a.memories.any(func(m: Memory) -> bool: return m.kind == "saw_0"), "the weakest went first")
	assert_eq(Social.memories_about(a, b.id)[0].kind, "saw_%d" % (Social.MEMORY_CAP + 4), "most salient first")
	sim.run_minutes(8 * DAY)
	for m: Memory in a.memories:
		assert_true(m.salience < 30.0)
	sim.run_minutes(10 * DAY)
	assert_true(a.memories.is_empty(), "all faded away")


func test_moodlets_lift_mood_and_end() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var before := Mood.compute(a, content())
	Social.add_moodlet(sim, a, "night_out")
	assert_eq(Mood.compute(a, content()), before + content().moodlet("night_out").value)
	Social.add_moodlet(sim, a, "night_out")
	assert_eq(a.moodlets.size(), 1, "the same moodlet restarts instead of stacking")
	Social.add_moodlet(sim, a, "no_such_moodlet")
	assert_eq(a.moodlets.size(), 1)
	sim.run_minutes(int(content().moodlet("night_out").duration_hours * 60) + 1)
	assert_true(a.moodlets.is_empty())
	assert_eq(Social.moodlet_total(a, content()), 0.0, "its lift is gone (needs moved on meanwhile)")


func test_finishing_a_meal_gives_its_moodlet() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	player.free_will = false
	var stove := 0
	for id: int in sim.world.objects:
		if sim.world.objects[id].def_id == "stove" and sim.content.place_at(sim.world.objects[id].origin).id == "home_player":
			stove = id
	sim.submit(QueueInteractionCommand.new(player.id, "cook_meal", stove))
	sim.run_minutes(40)
	assert_true(player.moodlets.any(func(m: Moodlet) -> bool: return m.id == "good_meal"))


func test_everything_survives_saving_and_old_saves_are_empty() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	Social.change(sim, a, b.id, {"friendship": 12.5, "romance": 3.0})
	Social.remember(sim, a, "joked_with", [b.id] as Array[int], 20, 40.0)
	Social.add_moodlet(sim, a, "had_a_laugh")
	var loaded := SaveCodec.from_json(SaveCodec.to_json(sim), content())
	assert_true(loaded != null)
	assert_eq(Ser.to_json(loaded.world.player().to_dict()), Ser.to_json(a.to_dict()))
	var old := SaveCodec.from_json(FileAccess.get_file_as_string(V3_SAVE), content())
	for person: Person in old.world.people.values():
		assert_true(person.relationships.is_empty() and person.memories.is_empty() and person.moodlets.is_empty())


func test_bad_saved_social_data_is_rejected() -> void:
	var setup := _two()
	var sim: Sim = setup[0]
	Social.change(sim, setup[1], setup[2].id, {"friendship": 5.0})
	var data: Dictionary = JSON.parse_string(SaveCodec.to_json(sim))
	for person: Variant in data["world"]["people"]:
		if not (person as Dictionary)["relationships"].is_empty():
			(person as Dictionary)["relationships"][0]["friendship"] = 400.0
	assert_eq(SaveCodec.from_json(JSON.stringify(data), content()), null)
