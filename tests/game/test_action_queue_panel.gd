extends TestCase
## T-0028: the action queue panel's texts, progress and cancel buttons.

const ROOM: PackedStringArray = [
	"##########",
	"#@.......#",
	"#........#",
	"#........#",
	"##########",
]

var _old_content: ContentDB
var _old_sim: Sim


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim


func _action(interaction_id: String, state: String, minutes_done: int = 0) -> Action:
	var action := Action.new(interaction_id, 1)
	action.state = state
	action.minutes_done = minutes_done
	return action


func test_row_text_by_position_and_state() -> void:
	var db := content()
	assert_eq(ActionQueuePanel.row_text(_action("grab_snack", Action.ROUTING), 0, db), "Grab a snack · walking there")
	assert_eq(ActionQueuePanel.row_text(_action("grab_snack", Action.QUEUED), 0, db), "Grab a snack · walking there")
	assert_eq(ActionQueuePanel.row_text(_action("grab_snack", Action.PERFORMING), 0, db), "Grab a snack")
	assert_eq(ActionQueuePanel.row_text(_action("watch_tv", Action.QUEUED), 1, db), "Then: Watch TV")
	assert_eq(ActionQueuePanel.row_text(_action("no_such_thing", Action.QUEUED), 2, db), "Then: no_such_thing")


func test_progress_for_fixed_and_until_need_actions() -> void:
	var db := content()
	var person := Person.new()
	person.needs["energy"] = 55.0
	assert_near(ActionQueuePanel.progress(_action("grab_snack", Action.PERFORMING, 2), person, db), 0.4)
	assert_near(ActionQueuePanel.progress(_action("sleep", Action.PERFORMING, 30), person, db), 0.55)
	assert_near(ActionQueuePanel.progress(_action("grab_snack", Action.ROUTING, 2), person, db), 0.0)


func test_signature_changes_with_the_queue_not_with_minutes() -> void:
	var person := Person.new()
	var first := _action("grab_snack", Action.ROUTING)
	person.action_queue = [first]
	var before := ActionQueuePanel.signature(person)
	first.state = Action.PERFORMING
	var performing := ActionQueuePanel.signature(person)
	assert_ne(performing, before, "a new state rebuilds the rows")
	first.minutes_done = 3
	assert_eq(ActionQueuePanel.signature(person), performing, "minutes only move the bar")
	person.action_queue.append(_action("watch_tv", Action.QUEUED))
	assert_ne(ActionQueuePanel.signature(person), performing, "a new action rebuilds the rows")


func test_the_cancel_button_cancels_that_row() -> void:
	var sim := SimFactory.from_rows(content(), ROOM)
	Session.content = content()
	Session.sim = sim
	var player := sim.world.player()
	player.action_queue = [_action("grab_snack", Action.ROUTING), _action("watch_tv", Action.QUEUED)]
	var panel := ActionQueuePanel.new()
	panel.show_person(player, content())
	assert_true(panel.visible)
	var second_row: HBoxContainer = panel._rows.get_child(1)
	var cancel: Button = second_row.get_child(second_row.get_child_count() - 1)
	cancel.pressed.emit()
	panel.free()
	var pending := sim.pending_commands()
	assert_eq(pending.size(), 1)
	if pending.size() == 1:
		var command := pending[0] as CancelActionCommand
		assert_true(command != null, "expected a CancelActionCommand")
		if command != null:
			assert_eq(command.person_id, player.id)
			assert_eq(command.index, 1)


func test_the_panel_hides_with_an_empty_queue() -> void:
	var panel := ActionQueuePanel.new()
	panel.show_person(Person.new(), content())
	assert_false(panel.visible)
	panel.free()
