extends TestCase


class MinuteCounter extends SimSystem:
	var minutes: int = 0

	func on_minute(_sim: Sim) -> void:
		minutes += 1


func test_tick_zero_is_monday_midnight() -> void:
	var clock := SimClock.new()
	assert_eq(clock.format(), "Mon 00:00")
	assert_eq(clock.day(), 0)
	assert_eq(clock.weekday(), 0)


func test_calendar_math() -> void:
	var clock := SimClock.new()
	clock.tick = SimClock.ticks_for(1, 8, 30)
	assert_eq(clock.day(), 1)
	assert_eq(clock.hour(), 8)
	assert_eq(clock.minute(), 30)
	assert_eq(clock.format(), "Tue 08:30")


func test_week_wraps_to_monday() -> void:
	var clock := SimClock.new()
	clock.tick = SimClock.ticks_for(7, 23, 59)
	assert_eq(clock.format(), "Mon 23:59")
	assert_eq(clock.day(), 7)


func test_new_game_starts_monday_0800() -> void:
	var sim := SimFactory.from_rows(content(), ["#@#"])
	assert_eq(sim.clock.format(), "Mon 08:00")


func test_on_minute_runs_once_per_game_minute() -> void:
	var sim := SimFactory.from_rows(content(), ["#@#"])
	var counter := MinuteCounter.new()
	sim.systems.append(counter)
	sim.run_steps(SimClock.STEPS_PER_GAME_MINUTE * 5)
	assert_eq(counter.minutes, 5)
	sim.run_steps(SimClock.STEPS_PER_GAME_MINUTE - 1)
	assert_eq(counter.minutes, 5, "no call before the minute is complete")
	sim.run_steps(1)
	assert_eq(counter.minutes, 6)


func test_clock_save_roundtrip() -> void:
	var clock := SimClock.new()
	clock.tick = 123456
	assert_eq(SimClock.from_dict(clock.to_dict()).tick, 123456)
