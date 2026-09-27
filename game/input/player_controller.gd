class_name PlayerController
extends Node
## Direct control: turns WASD/arrow keys into SetMoveIntentCommands for the player.
## Only sends a command when the direction actually changes.

## Optional fixed direction (set from the --walk command-line option, for screenshots).
var forced_direction: Vector2 = Vector2.ZERO

var _last_sent: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if forced_direction != Vector2.ZERO:
		direction = forced_direction
	if not direction.is_equal_approx(_last_sent):
		_last_sent = direction
		Session.submit(SetMoveIntentCommand.new(player.id, direction))


## Call after loading a game so the next key press is always sent.
func reset() -> void:
	_last_sent = Vector2.ZERO
