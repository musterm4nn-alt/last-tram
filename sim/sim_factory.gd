class_name SimFactory
extends RefCounted
## Builds new Sims: a fresh game from the authored districts, or a tiny world from ASCII
## rows for tests:
##
##     var sim := SimFactory.from_rows(ContentDB.load_default(), [
##         "#####",
##         "#@..#",
##         "#####",
##     ])
##
## In from_rows, "@" marks the player's start cell (it becomes wooden floor).

## New games start on Monday at 08:00.
const START_TICK: int = 8 * SimClock.MINUTES_PER_HOUR * SimClock.STEPS_PER_GAME_MINUTE


static func new_game(content: ContentDB, seed_value: int, spec: CharacterSpec = null) -> Sim:
	var world_size := Vector2i.ZERO
	for district_id: String in content.district_order:
		var district: DistrictDef = content.districts[district_id]
		world_size = world_size.max(district.origin + district.size)
	var grid := WorldGrid.new(content, world_size.x, world_size.y)
	for district_id: String in content.district_order:
		var district: DistrictDef = content.districts[district_id]
		for level: int in district.levels:
			grid.stamp_rows(level, district.origin, district.levels[level])
	var sim := _make_sim(content, grid, seed_value)
	var start: DistrictDef = content.districts[content.start_district]
	_spawn_player(sim, start.player_spawn, spec if spec != null else CharacterSpec.default_player(content))
	return sim


static func from_rows(content: ContentDB, rows: PackedStringArray, seed_value: int = 1) -> Sim:
	var width := 0
	for row: String in rows:
		width = maxi(width, row.length())
	var spawn := Vector3i(-1, -1, 0)
	var clean := PackedStringArray()
	for y: int in rows.size():
		var at := rows[y].find("@")
		if at >= 0:
			spawn = Vector3i(at, y, 0)
		clean.append(rows[y].replace("@", "."))
	var grid := WorldGrid.new(content, width, rows.size())
	grid.stamp_rows(0, Vector2i.ZERO, clean)
	var sim := _make_sim(content, grid, seed_value)
	if spawn.x >= 0:
		_spawn_player(sim, spawn, CharacterSpec.default_player(content))
	return sim


static func _make_sim(content: ContentDB, grid: WorldGrid, seed_value: int) -> Sim:
	var clock := SimClock.new()
	clock.tick = START_TICK
	return Sim.new(content, World.new(content, grid), clock, SimRng.new(seed_value))


static func _spawn_player(sim: Sim, cell: Vector3i, spec: CharacterSpec) -> Person:
	var person := Person.new()
	person.id = sim.world.new_id()
	spec.apply_to(person)
	person.level = cell.z
	person.pos = Vector2(cell.x + 0.5, cell.y + 0.5)
	person.prev_pos = person.pos
	for need_def: NeedDef in sim.content.needs:
		person.needs[need_def.id] = need_def.start
	sim.world.add_person(person)
	sim.world.player_id = person.id
	sim.emit_event(&"person_spawned", {"person_id": person.id})
	return person
