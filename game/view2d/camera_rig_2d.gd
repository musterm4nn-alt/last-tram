class_name CameraRig2D
extends Camera2D
## Follows the player. Mouse wheel or +/- zooms between ViewConfig.ZOOM_LEVELS.
## Camera limits keep the view inside the town.

var _zoom_index: int = ViewConfig.DEFAULT_ZOOM_INDEX


func _ready() -> void:
	_apply_zoom()
	Session.game_loaded.connect(_on_game_loaded)


func _on_game_loaded() -> void:
	var grid := Session.sim.world.grid
	limit_left = 0
	limit_top = 0
	limit_right = grid.width * ViewConfig.TILE_PX
	limit_bottom = grid.height * ViewConfig.TILE_PX
	_follow()
	reset_smoothing()


func _process(_delta: float) -> void:
	_follow()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_zoom_index = mini(_zoom_index + 1, ViewConfig.ZOOM_LEVELS.size() - 1)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		_zoom_index = maxi(_zoom_index - 1, 0)
		_apply_zoom()


## Index into ViewConfig.ZOOM_LEVELS (clamped).
func set_zoom_index(index: int) -> void:
	_zoom_index = clampi(index, 0, ViewConfig.ZOOM_LEVELS.size() - 1)
	_apply_zoom()


func _follow() -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player != null:
		position = player.prev_pos.lerp(player.pos, Session.alpha) * ViewConfig.TILE_PX


func _apply_zoom() -> void:
	var z := ViewConfig.ZOOM_LEVELS[_zoom_index]
	zoom = Vector2(z, z)
