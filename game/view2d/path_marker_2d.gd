class_name PathMarker2D
extends Node2D
## A small ring on the cell the player is walking to (WalkToCommand, or walking to an
## object). Nothing is drawn while the player has no path. Reads sim state only.

## Ring radius in cells.
const RADIUS_CELLS: float = 0.35
## Ring line width in pixels.
const WIDTH_PX: float = 2.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if Session.sim == null:
		return
	var player := Session.sim.world.player()
	if player == null:
		return
	var centre: Variant = marker_centre(player, Session.viewed_level)
	if centre == null:
		return
	draw_arc(centre, RADIUS_CELLS * ViewConfig.TILE_PX, 0.0, TAU, 32, ViewConfig.PLAYER_MARKER_COLOR, WIDTH_PX)


## Centre (pixels) of the player's destination, or null when there is none to show:
## the path is empty, or it ends on another level.
static func marker_centre(person: Person, level: int) -> Variant:
	if person.path.is_empty():
		return null
	var last: Vector3i = person.path[person.path.size() - 1]
	if last.z != level:
		return null
	return Vector2(last.x + 0.5, last.y + 0.5) * ViewConfig.TILE_PX
