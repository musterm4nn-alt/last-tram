extends TestCase
## T-0038: person-targeted interactions: walking over, the exchange, and its outcome.

const ROOM: PackedStringArray = [
	"############",
	"#@.........#",
	"#..........#",
	"############",
]


## The player at (1, 1) and someone else at `cell`; both without free will.
func _pair(cell: Vector3i = Vector3i(8, 2, 0)) -> Array:
	var sim := SimFactory.from_rows(content(), ROOM)
	var other := SimFactory.spawn_person(sim, cell, CharacterSpec.default_player(content()))
	sim.world.player().free_will = false
	other.free_will = false
	return [sim, sim.world.player(), other]


func _exchanges(sim: Sim) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events.drain():
		if event["type"] == &"social_exchange":
			out.append(event["data"])
	return out


func test_social_interactions_load_and_only_people_offer_them() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	var setup := _pair()
	var sim: Sim = setup[0]
	var ids: Array[String] = []
	for def: InteractionDef in Interactions.offered_by_person(sim, setup[1].id, setup[2].id):
		ids.append(def.id)
	assert_eq(ids, ["chat", "joke", "compliment", "insult", "argue", "flirt"] as Array[String])
	assert_true(Interactions.offered_by_person(sim, setup[1].id, setup[1].id).is_empty(), "not with yourself")
	var full := SimFactory.new_game(content(), 1)
	for id: int in full.world.objects:
		for def: InteractionDef in Interactions.offered_by(full, id):
			assert_eq(def.target, "object")


func test_a_chat_walks_over_talks_and_changes_both() -> void:
	var setup := _pair()
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	var social_before: float = a.needs["social"]
	sim.submit(QueueInteractionCommand.new(a.id, "chat", b.id))
	sim.run_minutes(6)
	var exchanges := _exchanges(sim)
	assert_eq(exchanges.size(), 1)
	assert_eq(exchanges[0]["interaction_id"], "chat")
	assert_true(Conversations.adjacent(a, b), "talked standing next to each other")
	assert_true(Social.relationship(a, b.id).familiarity > 0.0)
	assert_true(Social.relationship(b, a.id).familiarity > 0.0)
	assert_false(Social.memories_about(a, b.id).is_empty())
	assert_false(Social.memories_about(b, a.id).is_empty())
	assert_true(a.needs["social"] > social_before - 1.0, "talking filled Social")
	assert_true(a.action_queue.is_empty())


func test_friends_accept_more_than_enemies_and_kindness_helps() -> void:
	var setup := _pair(Vector3i(2, 1, 0))
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	var chat := content().interaction("chat")
	var stranger := Conversations.acceptance(sim, a, b, chat)
	Social.set_values(b, a.id, {"friendship": 60.0, "familiarity": 80.0}, 0)
	var friend := Conversations.acceptance(sim, a, b, chat)
	Social.set_values(b, a.id, {"friendship": -60.0, "familiarity": 80.0}, 0)
	var enemy := Conversations.acceptance(sim, a, b, chat)
	assert_true(friend > stranger and stranger > enemy, "%s > %s > %s" % [friend, stranger, enemy])
	b.personality.set_axis("kindness", 100)
	assert_true(Conversations.acceptance(sim, a, b, chat) > enemy, "a kind person forgives more")
	var flirt := content().interaction("flirt")
	Social.set_values(b, a.id, {"friendship": 0.0, "familiarity": 0.0, "romance": 0.0}, 0)
	assert_true(Conversations.acceptance(sim, a, b, flirt) < 0.5, "flirting with a stranger rarely lands")


func test_outcomes_follow_the_odds_and_repeat_with_the_seed() -> void:
	var results: Array[String] = []
	for run: int in 2:
		var setup := _pair(Vector3i(2, 1, 0))
		var sim: Sim = setup[0]
		var successes := 0
		for i: int in 200:
			if Conversations.resolve(sim, setup[1], setup[2], content().interaction("joke")) == "success":
				successes += 1
		results.append(str(successes))
	assert_eq(results[0], results[1], "same seed, same rolls")
	assert_true(int(results[0]) > 50 and int(results[0]) < 200, "jokes land sometimes: %s" % results[0])


func test_a_landed_insult_hurts() -> void:
	var setup := _pair(Vector3i(2, 1, 0))
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	var insult := content().interaction("insult")
	var outcome := ""
	for i: int in 20:
		outcome = Conversations.resolve(sim, a, b, insult)
		if outcome == "success":
			break
	assert_eq(outcome, "success")
	assert_true(Social.relationship(b, a.id).friendship < 0.0)
	assert_true(b.moodlets.any(func(m: Moodlet) -> bool: return m.id == "insulted"))
	assert_true(Mood.compute(b, content()) < 20.0)


func test_no_talking_to_someone_asleep() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var player := sim.world.player()
	var sleeper: Person = null
	sim.run_minutes(SimClock.MINUTES_PER_DAY - 8 * 60 + 4 * 60)  # 04:00
	for person: Person in sim.world.people.values():
		if person.id != player.id and not person.action_queue.is_empty() and person.action_queue[0].interaction_id == "sleep" and person.action_queue[0].state == Action.PERFORMING:
			sleeper = person
			break
	assert_true(sleeper != null, "someone is asleep at 04:00")
	sim.events.drain()
	player.action_queue.clear()  # the player is awake for this
	player.path.clear()
	player.free_will = false
	sim.submit(QueueInteractionCommand.new(player.id, "chat", sleeper.id))
	sim.run_steps(3)
	var failed := false
	for event: Dictionary in sim.events.drain():
		if event["type"] == &"action_failed" and int(event["data"]["person_id"]) == player.id:
			failed = event["data"]["reason"] == "target_busy"
	assert_true(failed)


func test_walking_away_ends_the_conversation() -> void:
	var setup := _pair(Vector3i(2, 1, 0))
	var sim: Sim = setup[0]
	var a: Person = setup[1]
	var b: Person = setup[2]
	sim.submit(QueueInteractionCommand.new(a.id, "argue", b.id))
	sim.run_steps(10)
	assert_eq(a.action_queue[0].state, Action.PERFORMING)
	sim.submit(WalkToCommand.new(b.id, Vector3i(10, 2, 0)))
	sim.run_minutes(1)
	assert_true(a.action_queue.is_empty(), "the target left")
	assert_true(_exchanges(sim).is_empty(), "no outcome without finishing")


func test_saving_mid_conversation_continues_identically() -> void:
	var straight: Sim = _pair()[0]
	straight.submit(QueueInteractionCommand.new(straight.world.player_id, "joke", _other(straight).id))
	straight.run_steps(150)
	for cut: int in [5, 40, 80]:
		var split: Sim = _pair()[0]
		split.submit(QueueInteractionCommand.new(split.world.player_id, "joke", _other(split).id))
		split.run_steps(cut)
		var resumed := SaveCodec.from_json(SaveCodec.to_json(split), content())
		resumed.run_steps(150 - cut)
		assert_eq(SaveCodec.to_json(resumed), SaveCodec.to_json(straight), "cut at %d" % cut)


func _other(sim: Sim) -> Person:
	for person: Person in sim.world.people.values():
		if person.id != sim.world.player_id:
			return person
	return null
