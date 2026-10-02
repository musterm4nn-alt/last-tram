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
## The simulation fidelity dial (T-0042).
var tiers: TierSettings = TierSettings.new()
## Varied or gentle jobs (T-0077).
var work: WorkSettings = WorkSettings.new()
## Discoveries whose once-per-world rewards (money) have been taken (T-0067; sorted).
var looted_discoveries: PackedStringArray = PackedStringArray()
## Money that entered and left people's hands, by reason (T-0054, D29).
var ledger: Ledger = Ledger.new()

var _next_id: int = 1
## Derived: place id -> lot id (rebuilt by lot_id_for_place when the lot count changes).
var _lot_by_place: Dictionary[String, int] = {}
var _lots_indexed: int = -1
## Derived footprint index: cell -> object ids covering it (rebuilt on load).
var _objects_by_cell: Dictionary = {}
## Derived: object tag -> ids of objects with it, in id order (objects_tagged; cleared when
## objects change).
var _objects_by_tag: Dictionary[String, Array] = {}
## Derived: lot id -> ids of the objects standing on it, in id order (objects_on_lot).
var _objects_by_lot: Dictionary[int, Array] = {}
var _objects_by_lot_built: bool = false


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
	_objects_by_tag.clear()
	_objects_by_lot_built = false
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
	_objects_by_tag.clear()
	_objects_by_lot_built = false


## Ids of the objects whose def has `tag`, in id order (T-0078: an index, so lookups such as a
## job's workplace don't scan every object).
func objects_tagged(tag: String) -> Array:
	if _objects_by_tag.is_empty():
		var ids: Array = objects.keys()
		ids.sort()
		for id: int in ids:
			var def := content.object_def(objects[id].def_id)
			for def_tag: String in def.tags if def != null else PackedStringArray():
				if not _objects_by_tag.has(def_tag):
					_objects_by_tag[def_tag] = []
				_objects_by_tag[def_tag].append(id)
	return _objects_by_tag.get(tag, [])


## Ids of the objects whose origin is on lot `lot_id`, in id order (T-0078: an index, so a
## person's home objects aren't found by scanning the town). Rebuilt when objects or lots change.
func objects_on_lot(lot_id: int) -> Array:
	if not _objects_by_lot_built or _objects_by_lot.get(-1, [0])[0] != lots.size():
		_objects_by_lot.clear()
		_objects_by_lot[-1] = [lots.size()]
		var ids: Array = objects.keys()
		ids.sort()
		for id: int in ids:
			var place := content.place_at(objects[id].origin)
			var on := lot_id_for_place(place.id) if place != null else 0
			if not _objects_by_lot.has(on):
				_objects_by_lot[on] = []
			_objects_by_lot[on].append(id)
		_objects_by_lot_built = true
	return _objects_by_lot.get(lot_id, []) if lot_id > 0 else []


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
		"tiers": tiers.to_dict(),
		"work": work.to_dict(),
		"looted_discoveries": Array(looted_discoveries),
		"ledger": ledger.to_dict(),
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
		# Clothes the content no longer has are dropped from the wardrobe.
		person.wardrobe = person.wardrobe.filter(func(w: WornItem) -> bool: return content.clothing_def(w.clothing_id) != null)
		# Skills the content no longer has are dropped.
		for skill_id: String in person.skills.keys():
			if content.skill(skill_id) == null:
				person.skills.erase(skill_id)
		# Clues and finds of discoveries the content no longer has are dropped.
		for key: String in ["known_clues", "discoveries"]:
			var kept := PackedStringArray()
			for id: String in person.get(key):
				if content.discovery(id) != null:
					kept.append(id)
			person.set(key, kept)
		# Jobs the content no longer has (or a position it lost) are dropped.
		if person.job != null:
			var job_def := content.job(person.job.job_id)
			if job_def == null or person.job.position >= job_def.positions.size():
				person.job = null
			else:
				person.job.level = mini(person.job.level, job_def.levels.size() - 1)
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
	var tiers_data: Variant = d.get("tiers", {})
	if tiers_data is Dictionary:
		world.tiers = TierSettings.from_dict(tiers_data)
	for id: Variant in d.get("looted_discoveries", []):
		if content.discovery(String(id)) != null:
			world.looted_discoveries.append(String(id))
	var work_data: Variant = d.get("work", {})
	if work_data is Dictionary:
		world.work = WorkSettings.from_dict(work_data)
	var ledger_data: Variant = d.get("ledger", {})
	if ledger_data is Dictionary:
		world.ledger = Ledger.from_dict(ledger_data)
	for household_entry: Variant in d.get("households", []):
		var household := Household.from_dict(household_entry)
		world.households[household.id] = household
	return world
