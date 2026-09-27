class_name PersonView2D
extends Node2D
## Draws one person from their appearance and outfit (see PersonDrawer2D), feet at the
## node's position. Position is interpolated between the last two sim steps for smooth
## movement.

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
	PersonDrawer2D.draw(self, Session.content, person.appearance, person.outfit, person.facing, float(ViewConfig.TILE_PX), person.id == Session.sim.world.player_id)
