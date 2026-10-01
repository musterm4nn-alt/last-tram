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
	InteractionLoader.load(self, reader, root.path_join("interactions"))
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


## The place containing a world cell, or null.
func place_at(cell: Vector3i) -> PlaceDef:
	for district_id: String in district_order:
		for place: PlaceDef in districts[district_id].places:
			if place.contains(cell):
				return place
	return null


## The clothing item with this id, or null.
func clothing_def(id: String) -> ClothingDef:
	return clothing.get(id)


## The object definition with this id, or null.
func object_def(id: String) -> ObjectDef:
	return objects.get(id)


## The interaction with this id, or null.
func interaction(id: String) -> InteractionDef:
	return interactions.get(id)
