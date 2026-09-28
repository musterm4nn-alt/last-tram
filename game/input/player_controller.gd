class_name PlayerController
extends Node
## Player input. Direct mode: WASD/arrow keys become SetMoveIntentCommands (only sent when
## the direction actually changes). Command mode (Session.command_mode): WASD pans the
## camera instead, and a left click on the ground walks the player there (WalkToCommand).

## Optional fixed direction (set from the --walk command-line option, for screenshots).
## Only used in direct mode.
var forced_direction: Vector2 = Vector2.ZERO
## The camera, for turning the mouse position into a world position (set by main.gd).
var camera: CameraRig2D

var _last_sent: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	var direction := Vector2.ZERO
	if not Session.command_mode:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if forced_direction != Vector2.ZERO:
			direction = forced_direction
	if not direction.is_equal_approx(_last_sent):
		_last_sent = direction
		Session.submit(SetMoveIntentCommand.new(player.id, direction))


func _unhandled_input(event: InputEvent) -> void:
	if not Session.command_mode or Session.sim == null or camera == null:
		return
	if not event.is_action_pressed("walk_click"):
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	Session.submit(walk_command(player, camera.get_global_mouse_position()))
	get_viewport().set_input_as_handled()


## The WalkToCommand for a click at `world_px`: the clicked cell on the player's level.
static func walk_command(player: Person, world_px: Vector2) -> WalkToCommand:
	var cell := ViewConfig.cell_at(world_px)
	return WalkToCommand.new(player.id, Vector3i(cell.x, cell.y, player.level))


## Call after loading a game so the next key press is always sent.
func reset() -> void:
	_last_sent = Vector2.ZERO
