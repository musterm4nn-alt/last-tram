class_name World
extends RefCounted
## All mutable state of the town: the grid and every entity in it.
## Entities reference each other by integer id only (never by object), and ids are unique
## across all entity kinds.

var content: ContentDB
var grid: WorldGrid
var people: Dictionary[int, Person] = {}
## Id of the person the player controls (0 = none).
var player_id: int = 0
## Every placed object by id.
var objects: Dictionary[int, WorldObject] = {}
## Every lot by id (one per place; see Lots).
var lots: Dictionary[int, Lot] = {}
## Every household by id.
var households: Dictionary[int, Household] = {}

var _next_id: int = 1
## Derived: place id -> lot id (rebuilt by lot_id_for_place when the lot count changes).
var _lot_by_place: Dictionary[String, int] = {}
var _lots_indexed: int = -1
## Derived footprint index: cell -> object ids covering it (rebuilt on load).
var _objects_by_cell: Dictionary = {}


func _init(p_content: ContentDB, p_grid: WorldGrid) -> void:
	content = p_content
	grid = p_grid


## The id of the lot covering `place_id`, or 0.
func lot_id_for_place(place_id: String) -> int:
	if _lots_indexed != lots.size():
		_lot_by_place.clear()
		for lot: Lot in lots.values():
			if not _lot_by_place.has(lot.place_id):
				_lot_by_place[lot.place_id] = lot.id
		_lots_indexed = lots.size()
	return _lot_by_place.get(place_id, 0)


func new_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func get_person(id: int) -> Person:
	return people.get(id)


func player() -> Person:
	return get_person(player_id)


## Adds a person. Give them an id from new_id() first.
func add_person(person: Person) -> void:
	people[person.id] = person


## "" if an object could be placed here, otherwise a reason ("unknown object",
## "bad rotation", "outside the map", "blocked terrain", "overlaps object 12").
func can_place(def_id: String, origin: Vector3i, rotation: int) -> String:
	var def := content.object_def(def_id)
	if def == null:
		return "unknown object"
	if rotation < 0 or rotation > 3:
		return "bad rotation"
	for offset: Vector2i in def.footprint(rotation):
		var cell := origin + Vector3i(offset.x, offset.y, 0)
		if not grid.in_bounds(cell):
			return "outside the map"
		if not content.terrain(grid.terrain_at(cell)).walkable:
			return "blocked terrain"
		var covering := objects_at(cell)
		if not covering.is_empty():
			return "overlaps object %d" % covering[0]
	return ""


## Stores an object and its blockers. False (and no change) if can_place fails.
## The caller emits &"object_added". World itself emits no events.
func add_object(obj: WorldObject) -> bool:
	if objects.has(obj.id):
		return false
	if can_place(obj.def_id, obj.origin, obj.rotation) != "":
		return false
	var def := content.object_def(obj.def_id)
	objects[obj.id] = obj
	for cell: Vector3i in obj.cells(content):
		if def.blocks_movement:
			grid.add_object_blocker(cell)
		if not _objects_by_cell.has(cell):
			_objects_by_cell[cell] = []
		(_objects_by_cell[cell] as Array).append(obj.id)
	return true


## Removes an object and its blockers. Does nothing if the id is unknown.
func remove_object(id: int) -> void:
	if not objects.has(id):
		return
	var obj: WorldObject = objects[id]
	var def := content.object_def(obj.def_id)
	for cell: Vector3i in obj.cells(content):
		if def != null and def.blocks_movement:
			grid.remove_object_blocker(cell)
		if _objects_by_cell.has(cell):
			(_objects_by_cell[cell] as Array).erase(id)
			if (_objects_by_cell[cell] as Array).is_empty():
				_objects_by_cell.erase(cell)
	objects.erase(id)


## The object with this id, or null.
func get_object(id: int) -> WorldObject:
	return objects.get(id)


## Ids of the objects whose footprint covers `cell`.
func objects_at(cell: Vector3i) -> Array[int]:
	var out: Array[int] = []
	if _objects_by_cell.has(cell):
		for id: Variant in (_objects_by_cell[cell] as Array):
			out.append(int(id))
	return out


func to_dict() -> Dictionary:
	var people_out: Array[Dictionary] = []
	for person: Person in people.values():
		people_out.append(person.to_dict())
	var objects_out: Array[Dictionary] = []
	for obj: WorldObject in objects.values():
		objects_out.append(obj.to_dict())
	var lots_out: Array[Dictionary] = []
	for lot: Lot in lots.values():
		lots_out.append(lot.to_dict())
	var households_out: Array[Dictionary] = []
	for household: Household in households.values():
		households_out.append(household.to_dict())
	return {
		"next_id": _next_id,
		"player_id": player_id,
		"grid": grid.to_dict(),
		"people": people_out,
		"objects": objects_out,
		"lots": lots_out,
		"households": households_out,
	}


static func from_dict(d: Dictionary, content: ContentDB) -> World:
	var world := World.new(content, WorldGrid.from_dict(d["grid"], content))
	world._next_id = int(d["next_id"])
	world.player_id = int(d["player_id"])
	for entry: Variant in d["people"]:
		var person := Person.from_dict(entry)
		for need_def: NeedDef in content.needs:
			if not person.needs.has(need_def.id):
				person.needs[need_def.id] = need_def.start
		# Needs the game no longer has (e.g. bladder, removed after v2 saves existed) are dropped.
		for need_id: String in person.needs.keys():
			if content.need(need_id) == null:
				person.needs.erase(need_id)
		world.add_person(person)
	# Old saves have no objects; unknown defs (e.g. from a removed content pack)
	# are skipped without logging errors.
	for obj_entry: Variant in d.get("objects", []):
		if not obj_entry is Dictionary:
			continue
		var obj := WorldObject.from_dict(obj_entry)
		if content.object_def(obj.def_id) == null:
			continue
		world.add_object(obj)
	# Lots of removed places are dropped. Saves from before lots get them all; saves with
	# lots get one for each newer place. (Worlds saved with no lots, like test rooms, stay
	# without.)
	var saved_lots: Array = d.get("lots", [])
	for lot_entry: Variant in saved_lots:
		var lot := Lot.from_dict(lot_entry)
		if world.content.place(lot.place_id) != null:
			world.lots[lot.id] = lot
	if not d.has("lots") or not saved_lots.is_empty():
		Lots.create_from_content(world, true)
	for household_entry: Variant in d.get("households", []):
		var household := Household.from_dict(household_entry)
		world.households[household.id] = household
	return world
