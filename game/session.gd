extends Node
## Autoload "Session": owns the running Sim and advances it in real time.
## It is the ONLY bridge between Godot (view, UI, input) and the sim:
##   read state:    Session.sim.world.player(), Session.sim.clock.format(), ...
##   change state:  Session.submit(SetMoveIntentCommand.new(id, dir))   (never write sim fields)
##   react:         Session.sim_event (incremental changes), Session.game_loaded (rebuild all)

## A sim event: {"type": StringName, "tick": int, "data": Dictionary}
signal sim_event(event: Dictionary)
## A new game started or a save was loaded: views must rebuild from world state.
signal game_loaded
signal speed_changed(speed: int)
## Short notice for the HUD ("Game saved").
signal notice(text: String)
## Tab switched between direct mode and command mode.
signal command_mode_changed(on: bool)

## 0 = paused. At 1x, one game minute passes per real second.
const MAX_SPEED: int = 3
## Safety valve: if the machine can't keep up, drop time instead of freezing.
const MAX_STEPS_PER_FRAME: int = 200
## While the player does a time_skip action (sleeping), one frame runs the sim until it ends,
## up to this many steps (one game day).
const SKIP_MAX_STEPS: int = 24 * 60 * SimClock.STEPS_PER_GAME_MINUTE
const SAVE_DIR: String = "user://saves"
## Where F9 bug reports go (tests pass their own folder).
const BUG_REPORT_DIR: String = "user://bug_reports"
## How many recent events a bug report's info.txt lists.
const REPORT_EVENTS: int = 20
const QUICKSAVE_PATH: String = "user://saves/quicksave.json"
## Retry a failed autosave after this many real seconds, without flooding notices.
const AUTOSAVE_RETRY_SECONDS: float = 10.0

var content: ContentDB
var sim: Sim
var speed: int = 1
## 0..1 progress towards the next step; views draw prev_pos.lerp(pos, alpha).
var alpha: float = 0.0
## Which floor level the 2D view shows (view state, not sim state). It follows the player
## whenever their level changes; command mode can page it (page_level).
var viewed_level: int = 0
## True in command mode: the camera pans freely and a click on the ground walks there
## (view state, not sim state; every new or loaded game starts in direct mode).
var command_mode: bool = false
## Commands applied since the last load: [{"tick", "command"}] (for bug reports/replays).
var command_log: Array[Dictionary] = []
## The save files: quicksave, slots and autosaves (tests swap in their own folder).
var saves: SaveSlots = SaveSlots.new(SAVE_DIR)
var steps_last_frame: int = 0
var sim_usec_last_frame: int = 0

var _accumulator: float = 0.0
var _speed_before_pause: int = 1
## The game day the last autosave was for (see SaveSlots.last_autosave_day_at).
var _last_autosave_day: int = -1
var _autosave_retry_left: float = 0.0
## The save the current stretch of play started from (at the last load or autosave), as
## JSON: a bug report replays command_log from here.
var _replay_start: String = ""
## The player's level the view last followed (see _follow_player_level).
var _followed_level: int = 0
## True while a sleep is being skipped (see SKIP_MAX_STEPS).
var skipping: bool = false
## started_tick of the action whose skipping a critical need stopped (-1 = none), so the
## same sleep does not start skipping again.
var _skip_stopped_tick: int = -1


func _ready() -> void:
	content = ContentDB.load_default()
	for error: String in content.errors:
		push_error("Content error: " + error)


func new_game(seed_value: int, spec: CharacterSpec = null) -> void:
	sim = SimFactory.new_game(content, seed_value, spec)
	_after_load()


func submit(command: Command) -> void:
	if sim != null:
		sim.submit(command)


func set_speed(new_speed: int) -> void:
	new_speed = clampi(new_speed, 0, MAX_SPEED)
	if new_speed == speed:
		return
	if new_speed == 0:
		_speed_before_pause = speed
	speed = new_speed
	speed_changed.emit(speed)


## Switches between direct and command mode; emits command_mode_changed only on a change.
## Direct mode always shows the player's floor.
func set_command_mode(on: bool) -> void:
	if on == command_mode:
		return
	command_mode = on
	if not on and sim != null and sim.world.player() != null:
		viewed_level = sim.world.player().level
	command_mode_changed.emit(on)


## Shows floor `level`, if the world has it.
func view_level(level: int) -> void:
	if sim != null and sim.world.grid.has_level(level):
		viewed_level = level


## Shows the next existing floor above (delta > 0) or below (delta < 0); nothing at the top
## or bottom.
func page_level(delta: int) -> void:
	if sim == null or delta == 0:
		return
	var best := viewed_level
	for level: int in sim.world.grid.levels():
		if delta > 0 and level > viewed_level and (best == viewed_level or level < best):
			best = level
		elif delta < 0 and level < viewed_level and (best == viewed_level or level > best):
			best = level
	viewed_level = best


func toggle_pause() -> void:
	set_speed(_speed_before_pause if speed == 0 else 0)


## Runs the sim forward instantly (used by --advance; later by sleep/work time skips).
func advance_minutes(minutes: int) -> void:
	if sim == null:
		return
	sim.run_minutes(minutes)
	command_log.append_array(sim.take_applied_commands())


func _process(delta: float) -> void:
	if sim == null:
		return
	_autosave_retry_left = maxf(0.0, _autosave_retry_left - delta)
	steps_last_frame = 0
	skipping = should_skip(sim, speed, _skip_stopped_tick)
	if speed > 0:
		var started := Time.get_ticks_usec()
		var accelerated := skipping
		var skipped_action: Action = sim.world.player().action_queue[0] if skipping else null
		var limit := SKIP_MAX_STEPS if accelerated else MAX_STEPS_PER_FRAME
		if accelerated:
			_accumulator = float(SKIP_MAX_STEPS)
		else:
			_accumulator += delta * SimClock.STEPS_PER_GAME_MINUTE * speed
		while _accumulator >= 1.0 and steps_last_frame < limit:
			sim.step()
			_accumulator -= 1.0
			steps_last_frame += 1
			command_log.append_array(sim.take_applied_commands())
			_forward_events()
			if accelerated and (not skipping or not should_skip(sim, speed, _skip_stopped_tick) or sim.world.player().action_queue[0] != skipped_action):
				skipping = false
				_accumulator = 0.0
				if not _woken_by_need(skipped_action):
					notice.emit("Woke up at %s" % sim.clock.format())
				break
		if steps_last_frame == limit:
			_accumulator = 0.0
		_follow_player_level()
		alpha = clampf(_accumulator, 0.0, 1.0)
		sim_usec_last_frame = Time.get_ticks_usec() - started
	command_log.append_array(sim.take_applied_commands())
	_forward_events()
	if steps_last_frame > 0 and _autosave_retry_left <= 0.0 and SaveSlots.autosave_due(sim.clock.tick, _last_autosave_day):
		autosave()


## True if a critical need ended the skip of `action` (that wake-up has its own notice).
func _woken_by_need(action: Action) -> bool:
	return action != null and _skip_stopped_tick == action.started_tick


## When the player's level changes (stairs), the view follows; a paged view stays put
## while the player stays on one floor.
func _follow_player_level() -> void:
	var player := sim.world.player()
	if player != null and player.level != _followed_level:
		_followed_level = player.level
		viewed_level = player.level


func _forward_events() -> void:
	for event: Dictionary in sim.events.drain():
		sim_event.emit(event)
		if skipping and event["type"] == &"need_critical" and int(event["data"].get("person_id", -1)) == sim.world.player_id:
			_stop_skipping(String(event["data"].get("need", "")))


# --- Saving and loading ----------------------------------------------------------------

func quicksave() -> void:
	if save_to(saves.quicksave_path()) == OK:
		notice.emit("Game saved")
	else:
		notice.emit("Saving failed")


func quickload() -> void:
	if load_from(saves.quicksave_path()):
		notice.emit("Game loaded")
	else:
		notice.emit("No quicksave to load")


## True when the player's front action is PERFORMING an interaction with time_skip, the
## game is not paused, and skipping was not stopped for this action (stopped_tick).
static func should_skip(p_sim: Sim, p_speed: int, stopped_tick: int) -> bool:
	if p_sim == null or p_speed <= 0:
		return false
	var player := p_sim.world.player()
	if player == null or player.action_queue.is_empty():
		return false
	var action: Action = player.action_queue[0]
	if action.state != Action.PERFORMING or action.started_tick == stopped_tick:
		return false
	var def := p_sim.content.interaction(action.interaction_id)
	return def != null and def.time_skip


## A critical need wakes the player: stop skipping for this sleep and say why.
func _stop_skipping(need_id: String) -> void:
	var player := sim.world.player()
	if player != null and not player.action_queue.is_empty():
		_skip_stopped_tick = player.action_queue[0].started_tick
	skipping = false
	var need_def := content.need(need_id)
	notice.emit("Woke up: %s is low" % (need_def.name if need_def != null else need_id))


## Writes the daily autosave into the older of the two autosave files.
func autosave() -> void:
	if sim == null:
		return
	if save_to(saves.next_autosave_path()) == OK:
		notice.emit("Autosaved")
	else:
		notice.emit("Autosave failed")
		_autosave_retry_left = AUTOSAVE_RETRY_SECONDS
		return
	_autosave_retry_left = 0.0
	_last_autosave_day = sim.clock.day()
	# The next bug report starts from here (command_log already holds every applied command).
	_replay_start = SaveCodec.to_json(sim)
	command_log.clear()


func save_to(path: String) -> Error:
	if sim == null:
		return ERR_UNCONFIGURED
	return SaveFile.new().write(path, SaveCodec.to_json(sim))


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(FileAccess.get_file_as_string(path), content, errors)
	if loaded == null:
		notice.emit("Load failed: " + "; ".join(errors))
		return false
	sim = loaded
	_after_load()
	return true


func _after_load() -> void:
	_accumulator = 0.0
	_autosave_retry_left = 0.0
	_skip_stopped_tick = -1
	skipping = false
	alpha = 0.0
	command_log.clear()
	sim.take_applied_commands()
	sim.events.drain()  # views rebuild from state on game_loaded, so skip creation events
	_replay_start = SaveCodec.to_json(sim)
	var player := sim.world.player()
	viewed_level = player.level if player != null else 0
	_followed_level = viewed_level
	set_command_mode(false)
	_last_autosave_day = SaveSlots.last_autosave_day_at(sim.clock.tick)
	game_loaded.emit()


# --- Bug reports (F9) -------------------------------------------------------------------

## Writes <base_dir>/<YYYY-MM-DD_HH-MM-SS>/ with start.json (where this stretch of play
## started), commands.json (every command applied since), end.json (the game now),
## screenshot.png (unless `screenshot` is null) and info.txt. Returns the folder's absolute
## path, or "" if writing failed. `tools/replay.sh <folder>` replays it.
func write_bug_report(screenshot: Image, base_dir: String = BUG_REPORT_DIR) -> String:
	if sim == null:
		return ""
	var stamp := Time.get_datetime_string_from_system(false, true).replace(" ", "_").replace(":", "-")
	var folder := base_dir.path_join(stamp)
	var suffix := 2
	while DirAccess.dir_exists_absolute(folder):
		folder = base_dir.path_join("%s_%d" % [stamp, suffix])
		suffix += 1
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var ok := _write_text(folder.path_join("start.json"), _replay_start)
	ok = _write_text(folder.path_join("commands.json"), Ser.to_json(command_log)) and ok
	ok = _write_text(folder.path_join("end.json"), SaveCodec.to_json(sim)) and ok
	ok = _write_text(folder.path_join("info.txt"), _report_info()) and ok
	if screenshot != null:
		ok = screenshot.save_png(folder.path_join("screenshot.png")) == OK and ok
	return ProjectSettings.globalize_path(folder) if ok else ""


## Plain words for info.txt: when, where, who, and what happened last.
func _report_info() -> String:
	var lines := PackedStringArray()
	lines.append("Last Tram bug report")
	lines.append("Real time: %s" % Time.get_datetime_string_from_system(false, true))
	lines.append("Game time: Day %d  %s" % [sim.clock.day() + 1, sim.clock.format()])
	var player := sim.world.player()
	if player != null:
		lines.append("Player: %s at %s" % [player.full_name(), player.cell()])
	lines.append("Speed: %s" % ("paused" if speed == 0 else "%dx" % speed))
	lines.append("Commands since the start save: %d" % command_log.size())
	lines.append("Recent events:")
	var recent := sim.events.recent
	for i: int in range(maxi(0, recent.size() - REPORT_EVENTS), recent.size()):
		lines.append("  %d %s %s" % [recent[i]["tick"], recent[i]["type"], recent[i]["data"]])
	return "\n".join(lines) + "\n"


static func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true
