extends TestCase
## T-0008: the needs panel shows one bar per need (data order), coloured by value, and
## the mood label. Built directly, outside the tree, like test_name_screen.gd.


func test_one_bar_per_need_in_data_order() -> void:
	var panel := _make_panel()
	var ids: Array = []
	for need_def: NeedDef in content().needs:
		ids.append(need_def.id)
	assert_eq(panel._bars.keys(), ids)
	assert_eq(panel._bars.size(), 6, "six needs in data/needs.json")
	panel.free()


func test_bars_show_values_and_colours() -> void:
	var panel := _make_panel()
	var person := Person.new()
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 80.0
	person.needs["hunger"] = 12.0
	person.needs["energy"] = 55.0
	panel.show_person(person, content())
	assert_near(panel._bars["hunger"].value, 12.0)
	assert_eq(panel._fills["hunger"].bg_color, NeedsPanel.LOW_COLOR)
	assert_near(panel._bars["energy"].value, 55.0)
	assert_eq(panel._fills["energy"].bg_color, NeedsPanel.OK_COLOR)
	assert_near(panel._bars["fun"].value, 80.0)
	assert_eq(panel._fills["fun"].bg_color, NeedsPanel.GOOD_COLOR)
	panel.free()


func test_mood_label() -> void:
	var panel := _make_panel()
	var person := Person.new()
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 100.0
	panel.show_person(person, content())
	assert_eq(panel._mood_label.text, "Mood: Fine")
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 0.0
	panel.show_person(person, content())
	assert_eq(panel._mood_label.text, "Mood: Miserable")
	panel.free()


func test_bar_color_thresholds() -> void:
	assert_eq(NeedsPanel.bar_color(100.0), NeedsPanel.GOOD_COLOR)
	assert_eq(NeedsPanel.bar_color(60.0), NeedsPanel.GOOD_COLOR)
	assert_eq(NeedsPanel.bar_color(59.9), NeedsPanel.OK_COLOR)
	assert_eq(NeedsPanel.bar_color(30.0), NeedsPanel.OK_COLOR)
	assert_eq(NeedsPanel.bar_color(29.9), NeedsPanel.LOW_COLOR)
	assert_eq(NeedsPanel.bar_color(0.0), NeedsPanel.LOW_COLOR)


func _make_panel() -> NeedsPanel:
	var panel := NeedsPanel.new()
	panel.build(content())
	return panel


func _performing(person: Person, interaction_id: String) -> void:
	var action := Action.new(interaction_id, 1)
	action.state = Action.PERFORMING
	person.action_queue = [action]


func test_is_rising_only_for_needs_the_action_fills_faster_than_they_decay() -> void:
	var person := Person.new()
	assert_false(NeedsPanel.is_rising(person, "fun", content()), "nothing to do, nothing rising")
	_performing(person, "watch_tv")
	assert_true(NeedsPanel.is_rising(person, "fun", content()), "TV: fun +25 per hour beats decay 6")
	assert_false(NeedsPanel.is_rising(person, "comfort", content()), "TV lowers comfort")
	person.action_queue[0].state = Action.ROUTING
	assert_false(NeedsPanel.is_rising(person, "fun", content()), "still walking to the TV")


func test_arrow_shows_next_to_a_rising_need() -> void:
	var panel := _make_panel()
	var person := Person.new()
	for need_def: NeedDef in content().needs:
		person.needs[need_def.id] = 50.0
	_performing(person, "watch_tv")
	panel.show_person(person, content())
	assert_eq(panel._arrows["fun"].text, "▲")
	assert_eq(panel._arrows["hunger"].text, "")
	panel.free()

