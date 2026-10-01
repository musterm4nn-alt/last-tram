extends TestCase
## advance_minutes fast-forwards the sim and forwards its events before returning, so a
## long --advance cannot leave a pile of pending events behind.

var _old_content: ContentDB
var _old_sim: Sim
var _old_command_log: Array[Dictionary] = []


func before_each() -> void:
	_old_content = Session.content
	_old_sim = Session.sim
	_old_command_log = Session.command_log.duplicate()


func after_each() -> void:
	Session.content = _old_content
	Session.sim = _old_sim
	Session.command_log = _old_command_log


func test_advance_minutes_forwards_events_and_runs_exact_time() -> void:
	Session.content = content()
	Session.new_game(1)
	var seen: Array[Dictionary] = []
	var listener := func(event: Dictionary) -> void: seen.append(event)
	Session.sim_event.connect(listener)
	Session.sim.emit_event(&"test_ping", {"value": 1})
	var started := Session.sim.clock.tick
	Session.advance_minutes(2)
	Session.sim_event.disconnect(listener)
	assert_eq(Session.sim.clock.tick, started + 2 * SimClock.STEPS_PER_GAME_MINUTE)
	var saw_ping := false
	for event: Dictionary in seen:
		if event["type"] == &"test_ping":
			saw_ping = true
	assert_true(saw_ping, "events are delivered by the time advance_minutes returns")
	assert_true(Session.sim.events.drain().is_empty(), "nothing stays pending after the advance")
