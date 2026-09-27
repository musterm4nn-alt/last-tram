class_name PersonView2D
extends Node2D
## Placeholder person: body, head and a facing dot, feet at the node's position.
## Position is interpolated between the last two sim steps for smooth movement.

var person_id: int = 0


func _process(_delta: float) -> void:
	var person := Session.sim.world.get_person(person_id)
	if person == null:
		return
	visible = person.level == Session.viewed_level
	position = person.prev_pos.lerp(person.pos, Session.alpha) * ViewConfig.TILE_PX
	queue_redraw()


func _draw() -> void:
	var person := Session.sim.world.get_person(person_id)
	if person == null:
		return
	var px := float(ViewConfig.TILE_PX)
	var body_color := ViewConfig.PLAYER_COLOR if person.id == Session.sim.world.player_id else ViewConfig.NPC_COLOR
	# Shadow, body, head (sizes in cells, scaled to pixels).
	draw_circle(Vector2(0, -0.02) * px, 0.28 * px, Color(0, 0, 0, 0.3))
	var body := Rect2(Vector2(-0.26, -0.95) * px, Vector2(0.52, 0.9) * px)
	draw_rect(body, body_color)
	draw_rect(body, ViewConfig.OUTLINE_COLOR, false, 1.0)
	var head_center := Vector2(0, -1.1) * px
	draw_circle(head_center, 0.24 * px, ViewConfig.SKIN_COLOR)
	draw_circle(head_center, 0.24 * px, ViewConfig.OUTLINE_COLOR, false, 1.0)
	draw_circle(head_center + person.facing * 0.14 * px, 0.06 * px, ViewConfig.OUTLINE_COLOR)
