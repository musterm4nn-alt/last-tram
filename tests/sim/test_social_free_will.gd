extends TestCase
## T-0039: free will considers talking to people nearby.

const ROOM: PackedStringArray = ["########", "#@.....#", "#......#", "########"]


func _pair() -> Array:
	var sim := SimFactory.from_rows(content(), ROOM)
	var other := SimFactory.spawn_person(sim, Vector3i(4, 2, 0), CharacterSpec.default_player(content()))
	other.free_will = false
	return [sim, sim.world.player(), other]


func _best_social(sim: Sim, person: Person) -> Dictionary:
	var best: Dictionary = {}
	for option: Dictionary in Autonomy.candidates(sim, person):
		if sim.world.get_person(int(option["object_id"])) == null:
			continue
		if best.is_empty() or float(option["score"]) > float(best["score"]):
			best = option
	return best


func test_a_lonely_person_talks_to_a_friend_in_the_room() -> void:
	var setup := _pair()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	a.needs["social"] = 15.0
	Social.set_values(a, b.id, {"friendship": 40.0, "familiarity": 60.0}, sim.clock.tick)
	a.last_input_tick = sim.clock.tick - AutonomySystem.IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE
	var talked := false
	for minute: int in 10:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] == &"social_exchange" and int(event["data"]["actor_id"]) == a.id:
				talked = true
	assert_true(talked)
	assert_true(a.needs["social"] > 15.0)


func test_content_people_leave_strangers_alone() -> void:
	var setup := _pair()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	a.needs["social"] = 100.0
	a.needs["fun"] = 100.0
	var best := _best_social(sim, a)
	assert_true(float(best["score"]) < Autonomy.MIN_SCORE, "best social option %s" % [best])


func test_insults_need_dislike_or_a_hot_temper() -> void:
	var setup := _pair()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	var insult := content().interaction("insult")
	var chat := content().interaction("chat")
	assert_true(Utility.social_bias(a, b, insult) < Utility.MEAN_PENALTY / 2.0, "no reason to insult a stranger")
	Social.set_values(a, b.id, {"friendship": -70.0}, 0)
	a.personality.set_axis("temper", 90)
	a.personality.set_axis("kindness", -50)
	a.needs["social"] = 40.0
	assert_true(Utility.social_bias(a, b, insult) > Utility.social_bias(a, b, chat), "a hot head insults an enemy")
	assert_true(Utility.social_bias(a, b, insult) > 0.0)


func test_romance_is_for_people_who_feel_it() -> void:
	var setup := _pair()
	var a: Person = setup[1]
	var b: Person = setup[2]
	var flirt := content().interaction("flirt")
	a.needs["social"] = 30.0
	assert_true(Utility.social_bias(a, b, flirt) < 0.0, "strangers don't flirt")
	Social.set_values(a, b.id, {"romance": 70.0, "friendship": 50.0}, 0)
	assert_true(Utility.social_bias(a, b, flirt) > 0.0, "partners do")


func test_two_days_in_town_make_new_acquaintances() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var exchanges := 0
	var stranger_flirts := 0
	for minute: int in 2 * SimClock.MINUTES_PER_DAY:
		sim.run_minutes(1)
		for event: Dictionary in sim.events.drain():
			if event["type"] != &"social_exchange":
				continue
			exchanges += 1
			if event["data"]["interaction_id"] == "flirt":
				var a := sim.world.get_person(int(event["data"]["actor_id"]))
				if a.household_id != sim.world.get_person(int(event["data"]["target_id"])).household_id:
					stranger_flirts += 1
	var acquaintances := 0
	for person: Person in sim.world.people.values():
		for r: Relationship in person.relationships.values():
			if sim.world.get_person(r.other_id).household_id != person.household_id and r.familiarity >= 10.0:
				acquaintances += 1
	assert_true(exchanges >= 100, "%d exchanges" % exchanges)
	assert_true(acquaintances >= 10, "%d new acquaintances" % acquaintances)
	assert_eq(stranger_flirts, 0, "nobody flirts with people they feel nothing for")
