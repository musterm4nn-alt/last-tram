class_name Sim
extends RefCounted
## The whole simulation: pure logic, no Godot nodes, no rendering, no input, no real time.
## Code outside sim/ may only (a) read state and (b) change it with submit(Command).
##
## Same seed + same commands at the same ticks = exactly the same result. Tests rely on it,
## and so do bug-report replays.

var content: ContentDB
var world: World
var clock: SimClock
var rng: SimRng
## Walking routes (a derived cache: never saved, rebuilds itself from the grid).
var nav: Pathfinder
var events: EventLog = EventLog.new()
var systems: Array[SimSystem] = []

var _pending: Array[Command] = []
## Commands applied since the last take_applied_commands(): [{"tick": int, "command": Dictionary}]
var _applied: Array[Dictionary] = []


func _init(p_content: ContentDB, p_world: World, p_clock: SimClock, p_rng: SimRng) -> void:
	content = p_content
	world = p_world
	clock = p_clock
	rng = p_rng
	nav = Pathfinder.new(world)
	systems = default_systems()


## Every system, in the order it runs each step and each minute. TierSystem goes first, so
## the minute's background updates use the latest tiers (T-0042).
## ActionSystem runs before MovementSystem (queued actions start before anyone
## moves) and before NeedsSystem (its per-minute rates apply before the decay,
## so one minute of sleep nets rate minus decay). SocialSystem ends moodlets before free
## will looks at mood. WorkSystem sends people to work before free will picks anything
## (obligations first, T-0060). PoliceSystem follows movement (an arrest needs this step's
## positions) and work (an officer must be on shift to be sent out). AutonomySystem runs last, so free
## will decides after the minute's needs have changed (D23, D24).
static func default_systems() -> Array[SimSystem]:
	return [
		TierSystem.new(),
		ActionSystem.new(),
		MovementSystem.new(),
		NeedsSystem.new(),
		SocialSystem.new(),
		WorkSystem.new(),
		PoliceSystem.new(),
		EconomySystem.new(),
		AutonomySystem.new(),
	]


## Queues a command; it is applied at the start of the next step.
func submit(command: Command) -> void:
	_pending.append(command)


func pending_commands() -> Array[Command]:
	return _pending


## Advances the sim by one step (3 game seconds).
func step() -> void:
	_apply_pending()
	for system: SimSystem in systems:
		system.step(self)
	clock.tick += 1
	if clock.is_minute_boundary():
		for system: SimSystem in systems:
			system.on_minute(self)


func run_steps(count: int) -> void:
	for i: int in count:
		step()


func run_minutes(minutes: int) -> void:
	run_steps(minutes * SimClock.STEPS_PER_GAME_MINUTE)


## Records something that happened, for the view/UI/tests (see EventLog).
func emit_event(type: StringName, data: Dictionary = {}) -> void:
	events.push(type, clock.tick, data)


## Returns and clears the log of applied commands (used for bug reports and replays).
func take_applied_commands() -> Array[Dictionary]:
	var out := _applied
	_applied = []
	return out


func _apply_pending() -> void:
	if _pending.is_empty():
		return
	var batch := _pending
	_pending = []
	for command: Command in batch:
		command.apply(self)
		_applied.append({"tick": clock.tick, "command": CommandRegistry.encode(command)})
