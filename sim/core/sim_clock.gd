class_name SimClock
extends RefCounted
## Game time. The sim advances in fixed steps and all time is derived from `tick`.
## One game minute = STEPS_PER_GAME_MINUTE steps. At 1x speed the game runs one game
## minute per real second, so a game day lasts 24 real minutes.
## Day 0 is a Monday; tick 0 is Monday 00:00 of day 0.

const STEPS_PER_GAME_MINUTE: int = 20
const MINUTES_PER_HOUR: int = 60
const MINUTES_PER_DAY: int = 1440
const DAYS_PER_WEEK: int = 7
const WEEKDAY_NAMES: PackedStringArray = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

## Steps since Monday 00:00 of day 0.
var tick: int = 0


## Number of steps in the given span of game time.
static func ticks_for(days: int, hours: int = 0, minutes: int = 0) -> int:
	return ((days * 24 + hours) * MINUTES_PER_HOUR + minutes) * STEPS_PER_GAME_MINUTE


func total_minutes() -> int:
	return tick / STEPS_PER_GAME_MINUTE


func day() -> int:
	return total_minutes() / MINUTES_PER_DAY


func minute_of_day() -> int:
	return total_minutes() % MINUTES_PER_DAY


func hour() -> int:
	return minute_of_day() / MINUTES_PER_HOUR


func minute() -> int:
	return minute_of_day() % MINUTES_PER_HOUR


## 0 = Monday ... 6 = Sunday.
func weekday() -> int:
	return day() % DAYS_PER_WEEK


## True right after the step that completed a game minute.
func is_minute_boundary() -> bool:
	return tick % STEPS_PER_GAME_MINUTE == 0


## "Mon 08:05"
func format() -> String:
	return "%s %02d:%02d" % [WEEKDAY_NAMES[weekday()], hour(), minute()]


func to_dict() -> Dictionary:
	return {"tick": tick}


static func from_dict(d: Dictionary) -> SimClock:
	var clock := SimClock.new()
	clock.tick = int(d["tick"])
	return clock
