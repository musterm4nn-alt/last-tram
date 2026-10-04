class_name PersonView2D
extends Node2D
## Draws one person from their appearance and outfit (see PersonDrawer2D), feet at the
## node's position. Position is interpolated between the last two sim steps for smooth
## movement.

var person_id: int = 0
var _walk_pose: WalkPose2D = WalkPose2D.new()


func _process(delta: float) -> void:
	var person := Session.sim.world.get_person(person_id)
	if person == null:
		return
	visible = person.level == Session.viewed_level and not Jobs.hidden(Session.sim, person) \
			and not Interiors.current.hidden(person.cell())
	position = person.prev_pos.lerp(person.pos, Session.alpha) * ViewConfig.TILE_PX
	_walk_pose.advance(delta, not person.pos.is_equal_approx(person.prev_pos), Session.speed, person.running)
	queue_redraw()


func _draw() -> void:
	var person := Session.sim.world.get_person(person_id)
	if person == null:
		return
	var is_player := person.id == Session.sim.world.player_id
	var sprite := WorldView2D.art.characters.sprite(person.id, is_player, person.facing, _walk_pose.walking, _walk_pose.elapsed)
	if sprite.is_empty():
		PersonDrawer2D.draw(self, Session.content, person.appearance, person.outfit, person.facing, float(ViewConfig.TILE_PX), is_player)
		return
	var region: Rect2i = sprite["region"]
	var at: Rect2 = sprite["draw_rect"]
	draw_texture_rect_region(sprite["texture"], at, Rect2(region))
	if is_player:
		var top := at.position.y - 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(-2, top), Vector2(2, top), Vector2(0, top + 3)]), ViewConfig.PLAYER_MARKER_COLOR)
