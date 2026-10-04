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
	visible = person.level == Session.viewed_level and not Jobs.hidden(Session.sim, person) \
			and not Interiors.current.hidden(person.cell())
	position = person.prev_pos.lerp(person.pos, Session.alpha) * ViewConfig.TILE_PX
	queue_redraw()


func _draw() -> void:
	var person := Session.sim.world.get_person(person_id)
	if person == null:
		return
	if not WorldView2D.art.people.is_empty():
		_draw_sprite(person, WorldView2D.art.people)
		return
	PersonDrawer2D.draw(self, Session.content, person.appearance, person.outfit, person.facing, float(ViewConfig.TILE_PX), person.id == Session.sim.world.player_id)


## PixelLab test: every person drawn from a base body in their own colours (PeopleSprites),
## walking while they move and breathing while they stand.
func _draw_sprite(person: Person, sheet: Dictionary) -> void:
	var facing := person.facing
	var row := 0
	if absf(facing.x) > absf(facing.y):
		row = 1 if facing.x > 0.0 else 3
	elif facing.y < 0.0:
		row = 2
	var walk: int = sheet["walk"]
	var ticks := Time.get_ticks_msec() + person.id * 97
	var col := int(ticks / 150) % walk if person.pos != person.prev_pos else walk + int(ticks / 300) % int(sheet["idle"])
	var frame: Vector2i = sheet["frame"]
	var feet: Vector2i = sheet["feet"]
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect_region(PeopleSprites.texture(sheet, Session.content, person.appearance, person.outfit), Rect2(-Vector2(feet), Vector2(frame)), Rect2(Vector2(col, row) * Vector2(frame), Vector2(frame)))
	if person.id == Session.sim.world.player_id:
		var top := -float(feet.y) + 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(-2, top), Vector2(2, top), Vector2(0, top + 3)]), ViewConfig.PLAYER_MARKER_COLOR)
