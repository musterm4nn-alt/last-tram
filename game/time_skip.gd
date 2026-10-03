class_name TimeSkip
extends RefCounted
## Skipping time while the player does a time_skip action (sleeping, working; T-0013,
## T-0059). Since T-0078 a skip runs over several frames, at most STEPS_PER_FRAME steps each,
## so the window never freezes; Esc stops it (stop). A critical need stops it too. View state
## only: the sim doesn't know time is being skipped.

## Steps per frame while skipping (one game hour).
const STEPS_PER_FRAME: int = 1200

## True while a skip is running.
var active: bool = false
## started_tick of the action whose skip was stopped (-1 = none), so the same action doesn't
## start skipping again.
var stopped_tick: int = -1


## True when the player's front action is PERFORMING an interaction with time_skip, the game
## isn't paused, and skipping wasn't stopped for this action (`p_stopped_tick`).
static func should_skip(sim: Sim, speed: int, p_stopped_tick: int) -> bool:
	if sim == null or speed <= 0:
		return false
	var player := sim.world.player()
	if player == null or player.action_queue.is_empty():
		return false
	var action: Action = player.action_queue[0]
	if action.state != Action.PERFORMING or action.started_tick == p_stopped_tick:
		return false
	var def := sim.content.interaction(action.interaction_id)
	return def != null and def.time_skip


## The notice when skipping `action` ends: "Woke up at 07:00" after sleep, "Back from work
## at 17:00" after a shift (T-0076); with `low_need`, why it stopped early ("Woke up: Hunger
## is low", "Stopped work: Hunger is low").
static func end_notice(sim: Sim, action: Action, low_need: String = "") -> String:
	var def := sim.content.interaction(action.interaction_id) if action != null else null
	var working := def != null and def.work
	if not low_need.is_empty():
		return "%s: %s is low" % ["Stopped work" if working else "Woke up", low_need]
	return "%s at %s" % ["Back from work" if working else "Woke up", sim.clock.format()]


## Stops skipping the player's current action for good (Esc, or a critical need).
func stop(sim: Sim) -> void:
	var player := sim.world.player() if sim != null else null
	if player != null and not player.action_queue.is_empty():
		stopped_tick = player.action_queue[0].started_tick
	active = false


func reset() -> void:
	active = false
	stopped_tick = -1
