class_name CameraRig2D
extends Camera2D
## Direct mode: follows the player. Command mode (Session.command_mode): stays put and pans
## with WASD/arrows or by dragging with the right mouse button. Mouse wheel or +/- zooms
## between ViewConfig.ZOOM_LEVELS (the wheel only over the town, not over a panel). Camera
## limits keep the view inside the town.

var _zoom_index: int = ViewConfig.DEFAULT_ZOOM_INDEX


func _ready() -> void:
	_apply_zoom()
	Session.game_loaded.connect(_on_game_loaded)
	Session.command_mode_changed.connect(_on_command_mode_changed)


func _on_game_loaded() -> void:
	var grid := Session.sim.world.grid
	limit_left = 0
	limit_top = 0
	limit_right = grid.width * ViewConfig.TILE_PX
	limit_bottom = grid.height * ViewConfig.TILE_PX
	_follow()
	reset_smoothing()


func _process(delta: float) -> void:
	if not Session.command_mode:
		_follow()
		return
	if Session.sim == null:
		return
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		position = clamp_to_town(pan_step(position, direction, delta, zoom.x), Session.sim.world.grid)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and wheel_over_ui(event as InputEventMouseButton, get_viewport().gui_get_hovered_control()):
		return  # a list that can't scroll further hands the wheel on; it mustn't become zoom
	if event.is_action_pressed("zoom_in"):
		_zoom_index = mini(_zoom_index + 1, ViewConfig.ZOOM_LEVELS.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		_zoom_index = maxi(_zoom_index - 1, 0)
		_apply_zoom()
	elif Session.command_mode and Session.sim != null and event is InputEventMouseMotion \
			and Input.is_action_pressed("pan_drag"):
		# Drag the town under the mouse.
		var motion := event as InputEventMouseMotion
		position = clamp_to_town(position - motion.relative / zoom.x, Session.sim.world.grid)


## True for a mouse-wheel event while the mouse is over a panel (the phone, a list, a menu):
## the wheel only zooms over the town itself, even when the panel has nothing left to scroll.
static func wheel_over_ui(event: InputEventMouseButton, hovered: Control) -> bool:
	var wheel := event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]
	return wheel and hovered != null


## Index into ViewConfig.ZOOM_LEVELS (clamped).
func set_zoom_index(index: int) -> void:
	_zoom_index = clampi(index, 0, ViewConfig.ZOOM_LEVELS.size() - 1)
	_apply_zoom()


## Command mode on, and the camera centred on `cell` (clamped to the town), e.g. to shoot the
## same view in every art set (--look-at).
func look_at_cell(cell: Vector2i) -> void:
	if Session.sim == null:
		return
	Session.set_command_mode(true)
	position = cell_centre(cell, Session.sim.world.grid)
	reset_smoothing()


## The pixel centre of `cell`, clamped to the town.
static func cell_centre(cell: Vector2i, grid: WorldGrid) -> Vector2:
	return clamp_to_town((Vector2(cell) + Vector2(0.5, 0.5)) * ViewConfig.TILE_PX, grid)


## `pos` clamped to the town in pixels: x in 0..grid.width*TILE_PX, y in 0..grid.height*TILE_PX.
static func clamp_to_town(pos: Vector2, grid: WorldGrid) -> Vector2:
	return Vector2(
		clampf(pos.x, 0.0, float(grid.width * ViewConfig.TILE_PX)),
		clampf(pos.y, 0.0, float(grid.height * ViewConfig.TILE_PX)))


## One frame of keyboard panning (pure, for tests): PAN_SPEED_PX screen pixels per second,
## so the same speed on screen at every zoom.
static func pan_step(pos: Vector2, direction: Vector2, delta: float, zoom_factor: float) -> Vector2:
	return pos + direction * ViewConfig.PAN_SPEED_PX * delta / zoom_factor


func _on_command_mode_changed(on: bool) -> void:
	if not on:
		_follow()
		reset_smoothing()


func _follow() -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player != null:
		position = player.prev_pos.lerp(player.pos, Session.alpha) * ViewConfig.TILE_PX


func _apply_zoom() -> void:
	var z := ViewConfig.ZOOM_LEVELS[_zoom_index]
	zoom = Vector2(z, z)
