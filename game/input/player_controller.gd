class_name PlayerController
extends Node
## Player input. Direct mode: WASD/arrow keys become SetMoveIntentCommands (only sent when
## the direction actually changes), and E opens the interaction menu for the nearest object.
## In both modes, holding Shift runs (SetRunningCommand, sent when the held state changes).
## Page Up/Down climbs the stairs the player stands on (direct mode) or pages the viewed
## floor (command mode); clicks in command mode act on the viewed floor.
## Command mode (Session.command_mode): WASD pans the camera instead; a left click on an
## object opens its menu, and a click on the ground walks the player there (WalkToCommand).

## Reach and preference for E: objects with a footprint cell centre within INTERACT_RANGE
## cells of the person count; distance is to the nearest such centre, minus FACING_BONUS
## when that centre is in front (facing.dot(direction) > 0.5).
const INTERACT_RANGE: float = 1.5
const FACING_BONUS: float = 0.5
## A person's clickable figure, in cells around and above their feet (person_at).
const PERSON_HALF_WIDTH: float = 0.4
const PERSON_HEIGHT: float = 1.4

## Optional fixed direction (set from the --walk command-line option, for screenshots).
## Only used in direct mode.
var forced_direction: Vector2 = Vector2.ZERO
## The camera, for turning the mouse position into a world position (set by main.gd).
var camera: CameraRig2D
## The interaction menu (set by main.gd). No walking while it is open.
var menu: InteractionMenu
## The person inspector (set by main.gd): a click on someone shows them, a click elsewhere
## hides it.
var inspector: PersonInspector
## The Esc menu (set by main.gd). No input at all while it is open.
var pause_menu: PauseMenu
## The full map (set by main.gd). No input at all while it is open.
var town_map: TownMap
## The scene popup (set by main.gd). No input at all while it is open.
var scene_popup: ScenePopup

var _last_sent: Vector2 = Vector2.ZERO
var _last_running: bool = false
var _needs_sync: bool = true


func _process(_delta: float) -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	var direction := Vector2.ZERO
	var running := false
	var menu_open := (menu != null and menu.visible) or (pause_menu != null and pause_menu.is_open) \
		or (town_map != null and town_map.is_open) or (scene_popup != null and scene_popup.is_open)
	if not menu_open:
		running = Input.is_action_pressed("run")
	if not Session.command_mode and not menu_open:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if forced_direction != Vector2.ZERO:
			direction = forced_direction
	if _needs_sync or running != _last_running:
		_last_running = running
		Session.submit(SetRunningCommand.new(player.id, running))
	if _needs_sync or not direction.is_equal_approx(_last_sent):
		_last_sent = direction
		Session.submit(SetMoveIntentCommand.new(player.id, direction))
	_needs_sync = false


func _unhandled_input(event: InputEvent) -> void:
	if Session.sim == null or camera == null or (pause_menu != null and pause_menu.is_open) \
		or (town_map != null and town_map.is_open) or (scene_popup != null and scene_popup.is_open):
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	if Session.command_mode and event.is_action_pressed("walk_click"):
		get_viewport().set_input_as_handled()
		var world_px := camera.get_global_mouse_position()
		var cell := ViewConfig.cell_at(world_px)
		var someone := person_at(Session.sim, world_px / ViewConfig.TILE_PX, Session.viewed_level, player.id)
		var here := Session.sim.world.objects_at(Vector3i(cell.x, cell.y, Session.viewed_level))
		if inspector != null:
			inspector.show_person(someone)
		if someone > 0 and menu != null:
			menu.open_for(someone, get_viewport().get_mouse_position())
		elif not here.is_empty() and menu != null:
			menu.open_for(here[0], get_viewport().get_mouse_position())
		else:
			Session.submit(walk_command(player, world_px, Session.viewed_level))
	elif event.is_action_pressed("level_up") or event.is_action_pressed("level_down"):
		get_viewport().set_input_as_handled()
		press_level_key(1 if event.is_action_pressed("level_up") else -1)
	elif not Session.command_mode and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		var object_id := nearest_target(Session.sim, player)
		if object_id > 0 and menu != null:
			menu.open_for(object_id, get_viewport().get_canvas_transform() * (player.pos * ViewConfig.TILE_PX))
		else:
			Session.notice.emit("Nothing to use here")


## Page Up (delta 1) / Page Down (-1): pages the viewed floor in command mode; in direct
## mode climbs the stairs the player stands on, or says "No stairs here".
func press_level_key(delta: int) -> void:
	if Session.command_mode:
		Session.page_level(delta)
		return
	var climb := stairs_command(Session.sim, Session.sim.world.player(), delta)
	if climb != null:
		Session.submit(climb)
	else:
		Session.notice.emit("No stairs here")


## The WalkToCommand for a click at `world_px`: the clicked cell on floor `level`.
static func walk_command(player: Person, world_px: Vector2, level: int) -> WalkToCommand:
	var cell := ViewConfig.cell_at(world_px)
	return WalkToCommand.new(player.id, Vector3i(cell.x, cell.y, level))


## A WalkTo up (delta 1) or down (delta -1) the stairs the player stands on, or null when
## their cell is not linked to the cell straight above or below.
static func stairs_command(sim: Sim, player: Person, delta: int) -> WalkToCommand:
	var here := player.cell()
	var there := here + Vector3i(0, 0, delta)
	if not sim.nav.is_stair_link(here, there):
		return null
	return WalkToCommand.new(player.id, there)


## The person whose figure covers `point` (in cells) on `level`, other than `except_id`, or 0.
## A figure covers PERSON_HALF_WIDTH to each side of the feet and PERSON_HEIGHT above them.
static func person_at(sim: Sim, point: Vector2, level: int, except_id: int) -> int:
	var best := 0
	var best_distance := INF
	for person: Person in sim.world.people.values():
		if person.id == except_id or person.level != level or Jobs.hidden(sim, person):
			continue
		var offset := point - person.pos
		if absf(offset.x) > PERSON_HALF_WIDTH or offset.y > 0.2 or offset.y < -PERSON_HEIGHT:
			continue
		var distance := offset.length()
		if distance < best_distance:
			best_distance = distance
			best = person.id
	return best


## What E would use: the best-scoring object or person in reach (people use the same reach
## and facing bonus as objects), or 0.
static func nearest_target(sim: Sim, person: Person) -> int:
	var object_id := nearest_object(sim, person)
	var person_id := nearest_person(sim, person)
	if person_id == 0:
		return object_id
	if object_id == 0:
		return person_id
	var object_score := _object_score(sim, person, sim.world.get_object(object_id))
	return person_id if _score(person, sim.world.get_person(person_id).pos) <= object_score else object_id


## The person E would talk to, or 0 if nobody is in reach. Ties: the lower id.
static func nearest_person(sim: Sim, person: Person) -> int:
	var best_id := 0
	var best_score := INF
	var ids: Array = sim.world.people.keys()
	ids.sort()
	for id: int in ids:
		var other: Person = sim.world.people[id]
		if id == person.id or other.level != person.level or Jobs.hidden(sim, other):
			continue
		var score := _score(person, other.pos)
		if score < best_score:
			best_score = score
			best_id = id
	return best_id


## Distance to `point` minus FACING_BONUS when it is in front; INF beyond INTERACT_RANGE.
static func _score(person: Person, point: Vector2) -> float:
	var offset := point - person.pos
	var distance := offset.length()
	if distance > INTERACT_RANGE:
		return INF
	var score := distance
	if distance > 0.0 and person.facing.dot(offset / distance) > 0.5:
		score -= FACING_BONUS
	return score


## The best _score over the object's footprint cell centres on the person's level.
static func _object_score(sim: Sim, person: Person, obj: WorldObject) -> float:
	var best := INF
	for cell: Vector3i in obj.cells(sim.content):
		if cell.z == person.level:
			best = minf(best, _score(person, Vector2(cell.x + 0.5, cell.y + 0.5)))
	return best


## The object E would use, or 0 if none is in reach. Ties: the lower object id.
static func nearest_object(sim: Sim, person: Person) -> int:
	var best_id := 0
	var best_score := INF
	var ids: Array = sim.world.objects.keys()
	ids.sort()
	for id: int in ids:
		var score := _object_score(sim, person, sim.world.objects[id])
		if score < best_score:
			best_score = score
			best_id = id
	return best_id


## Call after loading so held or released keys replace the saved movement intent.
func reset() -> void:
	_last_sent = Vector2.ZERO
	_last_running = false
	_needs_sync = true
	_process(0.0)  # Submit before Session can advance the first frame of the loaded game.
