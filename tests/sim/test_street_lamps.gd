extends TestCase
## T-0082: the Altstadt's street lamps stand on pavement, out of the way of doors and of
## other objects' use slots, and block no route.

var _sim: Sim


func before_each() -> void:
	_sim = SimFactory.new_game(content(), 1)


func test_lamps_stand_on_pavement() -> void:
	var world := _sim.world
	var slot_cells: Dictionary[Vector3i, int] = {}
	for obj: WorldObject in world.objects.values():
		if obj.def_id == "street_lamp":
			continue
		for i: int in obj.slot_count(_sim.content):
			slot_cells[obj.slot_cell(_sim.content, i)] = obj.id
	for lamp: WorldObject in _lamps():
		var cell := lamp.origin
		var terrain := world.grid.terrain_def_at(cell).id
		assert_true(terrain == "sidewalk" or terrain == "cobblestone", "lamp at %s stands on %s" % [cell, terrain])
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var near := cell + Vector3i(dx, dy, 0)
				if world.grid.in_bounds(near):
					assert_ne(world.grid.terrain_def_at(near).id, "door", "lamp at %s is next to a door" % [cell])
		assert_false(slot_cells.has(cell), "lamp at %s stands in a use slot of object %d" % [cell, slot_cells.get(cell, 0)])
		var here := world.objects_at(cell)
		assert_true(here.size() == 1 and here[0] == lamp.id, "lamp at %s shares its cell: %s" % [cell, here])


func test_lamps_block_no_route() -> void:
	assert_false(_sim.content.object_def("street_lamp").blocks_movement, "a lamp post is thin")
	for lamp: WorldObject in _lamps():
		assert_true(_sim.world.grid.is_walkable(lamp.origin), "people can still walk past at %s" % [lamp.origin])


func test_enough_lamps() -> void:
	var on_ground := _lamps().filter(func(lamp: WorldObject) -> bool: return lamp.origin.z == 0)
	assert_true(on_ground.size() >= 20, "%d lamps on level 0" % on_ground.size())


func _lamps() -> Array[WorldObject]:
	var out: Array[WorldObject] = []
	for obj: WorldObject in _sim.world.objects.values():
		if obj.def_id == "street_lamp":
			out.append(obj)
	return out
