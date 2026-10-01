extends TestCase
## T-0041: the person inspector panel.

var _old_content: ContentDB
var _old_sim: Sim


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	Session.content = content()


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim


func _resident(sim: Sim) -> Person:
	for household: Household in sim.world.households.values():
		if household.member_ids.size() == 2 and household.kind == Household.COUPLE:
			return sim.world.get_person(household.member_ids[0])
	return null


func test_lines_show_who_they_are_and_how_they_see_you() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var person := _resident(sim)
	var partner := sim.world.get_person(sim.world.households[person.household_id].member_ids[1])
	var lines := PersonInspector.lines(sim, person.id, sim.world.player_id)
	assert_eq(lines[0], person.full_name())
	assert_eq(lines[1], "%d, %s" % [person.age_years, person.pronouns])
	assert_true(lines[2].begins_with("Mood: "))
	assert_eq(lines[3], "Doing: Nothing")
	assert_true(lines[4].contains("with %s" % partner.display_name()), lines[4])
	assert_eq(lines[5], "Money: %s" % Money.format(person.wallet.total()))
	assert_true(person.wallet.total() > 0, "residents have starting money")
	assert_eq(lines[6], "Job: %s" % PersonInspector.job_text(sim, person))
	assert_eq(PersonInspector.job_text(sim, sim.world.player()), "Office clerk (Mon–Fri 9–17)")
	var someone := sim.world.player()
	someone.job = null
	assert_eq(PersonInspector.job_text(sim, someone), "Unemployed")
	someone.age_years = 70
	assert_eq(PersonInspector.job_text(sim, someone), "Retired")
	assert_has(lines, "You: a stranger")
	assert_has(lines, "  Remembers nothing about you yet.")


func test_memories_about_you_are_worded() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var person := _resident(sim)
	Social.change(sim, person, sim.world.player_id, {"familiarity": 30.0, "friendship": 30.0})
	Social.remember(sim, person, "laughed_with", [sim.world.player_id] as Array[int], 20, 50.0)
	Social.add_moodlet(sim, person, "had_a_laugh")
	var lines := PersonInspector.lines(sim, person.id, sim.world.player_id)
	assert_has(lines, "You: a friend")
	assert_has(lines, "  - laughed at your joke")
	assert_true(lines[2].contains("Had a laugh +10"), lines[2])


func test_relationship_words() -> void:
	var r := Relationship.new()
	assert_eq(PersonInspector.relationship_label(null), "a stranger")
	r.familiarity = 15.0
	assert_eq(PersonInspector.relationship_label(r), "knows you by sight")
	r.familiarity = 50.0
	assert_eq(PersonInspector.relationship_label(r), "knows you")
	r.friendship = 70.0
	assert_eq(PersonInspector.relationship_label(r), "a close friend")
	r.friendship = -30.0
	assert_eq(PersonInspector.relationship_label(r), "dislikes you")
	r.friendship = -80.0
	assert_eq(PersonInspector.relationship_label(r), "can't stand you")
	r.friendship = 10.0
	r.romance = 70.0
	assert_eq(PersonInspector.relationship_label(r), "in love with you")


func test_doing_names_the_action_and_who_with() -> void:
	var sim := SimFactory.new_game(content(), 1)
	var person := _resident(sim)
	var partner_id: int = sim.world.households[person.household_id].member_ids[1]
	var chat := Action.new("chat", partner_id)
	person.action_queue.append(chat)
	assert_true(PersonInspector.doing(sim, person).begins_with("Chat with "), PersonInspector.doing(sim, person))
	assert_true(PersonInspector.doing(sim, person).ends_with("(on the way)"))


func test_the_panel_shows_and_hides() -> void:
	Session.sim = SimFactory.new_game(content(), 1)
	var panel := PersonInspector.new()
	panel.show_person(_resident(Session.sim).id)
	assert_true(panel.visible)
	panel._process(0.0)
	assert_true(panel._label.text.contains("Mood:"))
	panel.show_person(0)
	assert_false(panel.visible)
	panel.free()


func test_doing_says_when_work_ends() -> void:
	var sim := SimFactory.new_game(content(), 1)
	sim.clock.tick = SimClock.ticks_for(0, 9)
	var player := sim.world.player()
	player.free_will = false
	var shelter: WorldObject = null
	for obj: WorldObject in sim.world.objects.values():
		if obj.def_id == "tram_stop":
			shelter = obj
	var cell := shelter.slot_cell(content(), 0)
	player.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	sim.submit(QueueInteractionCommand.new(player.id, "work", shelter.id))
	sim.step()
	assert_eq(PersonInspector.doing(sim, player), "At work until 17:00")
