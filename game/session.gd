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
const SAVE_DIR: String = "user://saves"
const QUICKSAVE_PATH: String = "user://saves/quicksave.json"

var content: ContentDB
var sim: Sim
var speed: int = 1
## 0..1 progress towards the next step; views draw prev_pos.lerp(pos, alpha).
var alpha: float = 0.0
## Which floor level the 2D view shows (view state, not sim state).
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
func set_command_mode(on: bool) -> void:
	if on == command_mode:
		return
	command_mode = on
	command_mode_changed.emit(on)


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
	steps_last_frame = 0
	if speed > 0:
		var started := Time.get_ticks_usec()
		_accumulator += delta * SimClock.STEPS_PER_GAME_MINUTE * speed
		while _accumulator >= 1.0 and steps_last_frame < MAX_STEPS_PER_FRAME:
			sim.step()
			_accumulator -= 1.0
			steps_last_frame += 1
		if steps_last_frame == MAX_STEPS_PER_FRAME:
			_accumulator = 0.0
		alpha = clampf(_accumulator, 0.0, 1.0)
		sim_usec_last_frame = Time.get_ticks_usec() - started
	command_log.append_array(sim.take_applied_commands())
	for event: Dictionary in sim.events.drain():
		sim_event.emit(event)
	if steps_last_frame > 0 and SaveSlots.autosave_due(sim.clock.tick, _last_autosave_day):
		autosave()


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


## Writes the daily autosave into the older of the two autosave files.
func autosave() -> void:
	if sim == null:
		return
	if save_to(saves.next_autosave_path()) == OK:
		notice.emit("Autosaved")
	else:
		notice.emit("Autosave failed")
	_last_autosave_day = sim.clock.day()


func save_to(path: String) -> Error:
	if sim == null:
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(SaveCodec.to_json(sim))
	file.close()
	return OK


func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var errors: Array[String] = []
	var loaded := SaveCodec.from_json(FileAccess.get_file_as_string(path), content, errors)
	if loaded == null:
		for error: String in errors:
			push_error("Load failed: " + error)
		return false
	sim = loaded
	_after_load()
	return true


func _after_load() -> void:
	_accumulator = 0.0
	alpha = 0.0
	command_log.clear()
	sim.take_applied_commands()
	sim.events.drain()  # views rebuild from state on game_loaded, so skip creation events
	var player := sim.world.player()
	viewed_level = player.level if player != null else 0
	set_command_mode(false)
	_last_autosave_day = SaveSlots.last_autosave_day_at(sim.clock.tick)
	game_loaded.emit()
