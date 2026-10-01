extends TestCase
## T-0040: speech and thought bubbles from systemic dialogue.

var _old_content: ContentDB
var _old_sim: Sim


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	Session.content = content()


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim


func test_dialogue_content_covers_every_social_interaction() -> void:
	assert_true(content().errors.is_empty(), "%s" % [content().errors])
	assert_false(content().dialogue.topics.is_empty())
	for def: InteractionDef in content().interactions.values():
		if def.target != "person":
			continue
		for outcome: String in SocialDef.OUTCOMES:
			var texts: PackedStringArray = content().dialogue.lines.get(def.id, {}).get(outcome, PackedStringArray())
			assert_false(texts.is_empty(), "lines for %s/%s" % [def.id, outcome])
	for need: NeedDef in content().needs:
		assert_true(content().dialogue.needs.has(need.id), "a thought for %s" % need.id)


func test_lines_fill_in_a_topic_and_repeat_for_the_same_exchange() -> void:
	var dialogue := SystemicDialogue.new(content())
	var exchange := {"actor_id": 5, "target_id": 9, "interaction_id": "chat", "outcome": "success", "tick": 1234}
	var line := dialogue.line_for(exchange, null)
	assert_false(line.is_empty())
	assert_false(line.contains("{topic}"), line)
	assert_eq(dialogue.line_for(exchange, null), line, "the same exchange, the same words")
	var seen: Dictionary[String, bool] = {}
	for tick: int in 40:
		exchange["tick"] = tick
		seen[dialogue.line_for(exchange, null)] = true
	assert_true(seen.size() > 3, "variety: %d lines" % seen.size())
	assert_eq(dialogue.line_for({"interaction_id": "sleep", "outcome": "success"}, null), "")
	assert_eq(dialogue.thought_for("hunger"), "Hungry...")


func test_events_make_bubbles_that_fade() -> void:
	Session.sim = SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])
	var layer := BubblesLayer.new()
	layer.provider = SystemicDialogue.new(content())
	layer.on_sim_event({"type": &"social_exchange", "tick": 7, "data": {"actor_id": 3, "target_id": 4, "interaction_id": "joke", "outcome": "fail"}})
	layer.on_sim_event({"type": &"need_critical", "tick": 8, "data": {"person_id": 4, "need": "fun"}})
	layer.on_sim_event({"type": &"action_finished", "tick": 9, "data": {"person_id": 5}})
	assert_eq(layer.bubbles.size(), 2)
	assert_false(layer.bubbles[3]["thought"])
	assert_eq(layer.bubbles[4]["text"], "Bored...")
	assert_true(layer.bubbles[4]["thought"])
	layer._process(BubblesLayer.BUBBLE_SECONDS + 0.1)
	assert_true(layer.bubbles.is_empty(), "gone after a few seconds")
	layer.free()
