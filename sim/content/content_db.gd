class_name ContentDB
extends RefCounted
## All game content from data/, loaded once at startup and validated. Read-only at runtime.
## Loading never crashes: problems are collected in `errors` (tests require it to be empty).
## Each kind of content has its own loader in sim/content/ (TerrainLoader, NeedsLoader...).
## To add a new kind, see docs/cookbook.md -> "Add a new kind of content".

const DATA_ROOT: String = "res://data"
## Name lists every game must have (data/names/names.json).
const FIRST_NAME_LISTS: PackedStringArray = ["feminine", "masculine", "neutral"]

var terrains: Array[TerrainDef] = []
var needs: Array[NeedDef] = []
var districts: Dictionary[String, DistrictDef] = {}
## District ids in the order they are stamped into the world.
var district_order: Array[String] = []
var start_district: String = ""
## World-object definitions by id, loaded from every file in data/objects/.
var objects: Dictionary[String, ObjectDef] = {}
## Interactions by id, loaded from every file in data/interactions/.
var interactions: Dictionary[String, InteractionDef] = {}
## Bubble text for the view (data/dialogue/, T-0040).
var dialogue: DialogueDef = DialogueDef.new()
## Temporary mood modifiers by id (data/moodlets.json).
var moodlets: Dictionary[String, MoodletDef] = {}
## Daily rhythms by id (data/routines.json) and the id people get by default.
var routines: Dictionary[String, RoutineDef] = {}
var default_routine: String = ""
var errors: PackedStringArray = []

## Every choice the character creator offers (genders, colours, hair, names...).
var appearance: AppearanceCatalog = AppearanceCatalog.new()
## Clothing items by id, loaded from every file in data/clothing/items/.
var clothing: Dictionary[String, ClothingDef] = {}
## Clothing colour options by id, from data/clothing/colours.json.
var clothing_colours: Dictionary[String, ColorOption] = {}
## First names per name list (see FIRST_NAME_LISTS).
var first_names: Dictionary[String, PackedStringArray] = {}
var last_names: PackedStringArray = PackedStringArray()
## The default player identity (data/appearance/default_player.json) in CharacterSpec
## to_dict() shape, used for new games when no character was created.
var default_player: Dictionary = {}

var _terrain_by_id: Dictionary[String, int] = {}
var _terrain_by_glyph: Dictionary[String, int] = {}
var _need_by_id: Dictionary[String, NeedDef] = {}
## Derived place lookup for place_at (rebuilt when the places change): per level, one entry
## per cell of _place_area, holding 1 + the index into _place_list (0 = no place).
var _place_grid: Dictionary[int, PackedInt32Array] = {}
var _place_list: Array[PlaceDef] = []
var _place_area: Vector2i = Vector2i.ZERO
var _place_signature: int = -1


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_from(DATA_ROOT)
	return db


## Load every domain in dependency order (terrain before world for glyph checks,
## names before appearance for name-list checks, colours before clothing items).
func load_from(root: String) -> void:
	var reader := ContentReader.new()
	TerrainLoader.load(self, reader, root.path_join("terrain.json"))
	NeedsLoader.load(self, reader, root.path_join("needs.json"))
	NamesLoader.load(self, reader, root.path_join("names").path_join("names.json"))
	AppearanceLoader.load(self, reader, root.path_join("appearance").path_join("appearance.json"))
	ClothingLoader.load(self, reader, root.path_join("clothing"))
	ObjectLoader.load(self, reader, root.path_join("objects"))
	MoodletLoader.load(self, reader, root.path_join("moodlets.json"))
	InteractionLoader.load(self, reader, root.path_join("interactions"))
	RoutineLoader.load(self, reader, root.path_join("routines.json"))
	DialogueLoader.load(self, reader, root.path_join("dialogue"))
	WorldLoader.load(self, reader, root.path_join("world"))
	AppearanceLoader.load_default_player(self, reader, root.path_join("appearance").path_join("default_player.json"))
	for problem: String in reader.errors:
		errors.append(problem)


func is_valid() -> bool:
	return errors.is_empty()


## Appends a terrain and indexes its id and glyph (TerrainLoader reports duplicates first).
func add_terrain(t: TerrainDef) -> void:
	_terrain_by_id[t.id] = terrains.size()
	_terrain_by_glyph[t.glyph] = terrains.size()
	terrains.append(t)


## Appends a need and indexes its id (NeedsLoader reports duplicates first).
func add_need(n: NeedDef) -> void:
	_need_by_id[n.id] = n
	needs.append(n)


# --- Queries ---------------------------------------------------------------------------

## Index into `terrains`, or -1.
func terrain_index(terrain_id: String) -> int:
	return _terrain_by_id.get(terrain_id, -1)


## Index into `terrains` for an ASCII map glyph, or -1.
func terrain_index_for_glyph(glyph: String) -> int:
	return _terrain_by_glyph.get(glyph, -1)


func terrain(index: int) -> TerrainDef:
	return terrains[index]


## The NeedDef with the given id, or null.
func need(need_id: String) -> NeedDef:
	if _need_by_id.has(need_id):
		return _need_by_id[need_id]
	return null


## The place with this id (any district), or null.
func place(place_id: String) -> PlaceDef:
	for district_id: String in district_order:
		for candidate: PlaceDef in districts[district_id].places:
			if candidate.id == place_id:
				return candidate
	return null


## The place containing a world cell, or null. Where places overlap, the first in district
## and list order wins.
func place_at(cell: Vector3i) -> PlaceDef:
	_index_places()
	if cell.x < 0 or cell.y < 0 or cell.x >= _place_area.x or cell.y >= _place_area.y or not _place_grid.has(cell.z):
		return null
	var index := _place_grid[cell.z][cell.y * _place_area.x + cell.x]
	return _place_list[index - 1] if index > 0 else null


## Builds the place lookup the first time, and again whenever districts or places change.
func _index_places() -> void:
	var signature := districts.size()
	for district_id: String in district_order:
		signature = signature * 31 + districts[district_id].places.size()
	if signature == _place_signature:
		return
	_place_signature = signature
	_place_grid.clear()
	_place_list.clear()
	_place_area = Vector2i.ZERO
	for district_id: String in district_order:
		for place: PlaceDef in districts[district_id].places:
			_place_area = _place_area.max(place.rect.end)
	for district_id: String in district_order:
		for place: PlaceDef in districts[district_id].places:
			_place_list.append(place)
			if not _place_grid.has(place.level):
				var cells := PackedInt32Array()
				cells.resize(_place_area.x * _place_area.y)
				_place_grid[place.level] = cells
			var grid := _place_grid[place.level]
			for y: int in range(maxi(place.rect.position.y, 0), place.rect.end.y):
				for x: int in range(maxi(place.rect.position.x, 0), place.rect.end.x):
					if grid[y * _place_area.x + x] == 0:
						grid[y * _place_area.x + x] = _place_list.size()
			_place_grid[place.level] = grid


## The clothing item with this id, or null.
func clothing_def(id: String) -> ClothingDef:
	return clothing.get(id)


## The object definition with this id, or null.
func object_def(id: String) -> ObjectDef:
	return objects.get(id)


## The moodlet definition with this id, or null.
func moodlet(id: String) -> MoodletDef:
	return moodlets.get(id)


## The routine with this id, or null.
func routine(id: String) -> RoutineDef:
	return routines.get(id)


## The interaction with this id, or null.
func interaction(id: String) -> InteractionDef:
	return interactions.get(id)
