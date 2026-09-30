class_name PlayerController
extends Node
## Player input. Direct mode: WASD/arrow keys become SetMoveIntentCommands (only sent when
## the direction actually changes), and E opens the interaction menu for the nearest object.
## Command mode (Session.command_mode): WASD pans the camera instead; a left click on an
## object opens its menu, and a click on the ground walks the player there (WalkToCommand).

## Reach and preference for E: objects with a footprint cell centre within INTERACT_RANGE
## cells of the person count; distance is to the nearest such centre, minus FACING_BONUS
## when that centre is in front (facing.dot(direction) > 0.5).
const INTERACT_RANGE: float = 1.5
const FACING_BONUS: float = 0.5

## Optional fixed direction (set from the --walk command-line option, for screenshots).
## Only used in direct mode.
var forced_direction: Vector2 = Vector2.ZERO
## The camera, for turning the mouse position into a world position (set by main.gd).
var camera: CameraRig2D
## The interaction menu (set by main.gd). No walking while it is open.
var menu: InteractionMenu
## The Esc menu (set by main.gd). No input at all while it is open.
var pause_menu: PauseMenu

var _last_sent: Vector2 = Vector2.ZERO
var _needs_sync: bool = true


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	var direction := Vector2.ZERO
	var menu_open := (menu != null and menu.visible) or (pause_menu != null and pause_menu.is_open)
	if not Session.command_mode and not menu_open:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if forced_direction != Vector2.ZERO:
			direction = forced_direction
	if _needs_sync or not direction.is_equal_approx(_last_sent):
		_needs_sync = false
		_last_sent = direction
		Session.submit(SetMoveIntentCommand.new(player.id, direction))


func _unhandled_input(event: InputEvent) -> void:
	if Session.sim == null or camera == null or (pause_menu != null and pause_menu.is_open):
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	if Session.command_mode and event.is_action_pressed("walk_click"):
		get_viewport().set_input_as_handled()
		var world_px := camera.get_global_mouse_position()
		var cell := ViewConfig.cell_at(world_px)
		var here := Session.sim.world.objects_at(Vector3i(cell.x, cell.y, player.level))
		if not here.is_empty() and menu != null:
			menu.open_for(here[0], get_viewport().get_mouse_position())
		else:
			Session.submit(walk_command(player, world_px))
	elif not Session.command_mode and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var object_id := nearest_object(Session.sim, player)
		if object_id > 0 and menu != null:
			menu.open_for(object_id, get_viewport().get_canvas_transform() * (player.pos * ViewConfig.TILE_PX))
		else:
			Session.notice.emit("Nothing to use here")


## The WalkToCommand for a click at `world_px`: the clicked cell on the player's level.
static func walk_command(player: Person, world_px: Vector2) -> WalkToCommand:
	var cell := ViewConfig.cell_at(world_px)
	return WalkToCommand.new(player.id, Vector3i(cell.x, cell.y, player.level))


## The object E would use, or 0 if none is in reach. Ties: the lower object id.
static func nearest_object(sim: Sim, person: Person) -> int:
	var best_id := 0
	var best_score := INF
	var ids: Array = sim.world.objects.keys()
	ids.sort()
	for id: int in ids:
		var obj: WorldObject = sim.world.objects[id]
		for cell: Vector3i in obj.cells(sim.content):
			if cell.z != person.level:
				continue
			var offset := Vector2(cell.x + 0.5, cell.y + 0.5) - person.pos
			var distance := offset.length()
			if distance > INTERACT_RANGE:
				continue
			var score := distance
			if distance > 0.0 and person.facing.dot(offset / distance) > 0.5:
				score -= FACING_BONUS
			if score < best_score:
				best_score = score
				best_id = id
	return best_id


## Call after loading so held or released keys replace the saved movement intent.
func reset() -> void:
	_last_sent = Vector2.ZERO
	_needs_sync = true
	_process(0.0)  # Submit before Session can advance the first frame of the loaded game.
