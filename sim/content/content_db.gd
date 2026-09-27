class_name ContentDB
extends RefCounted
## All game content from data/, loaded once at startup and validated. Read-only at runtime.
## Loading never crashes: problems are collected in `errors` (tests require it to be empty).
##
## To add a new kind of content (objects, interactions, jobs...):
##   1. a *Def class in sim/content/
##   2. a *Loader class in sim/content/ (see TerrainLoader), using ContentReader
##   3. a call to it in load_from(), in dependency order (needs before world, ...)
##   4. validation of every reference it makes (ids that must exist)
##   5. a test in tests/sim/test_content.gd

const DATA_ROOT: String = "res://data"
## Name lists every game must have (data/names/names.json).
const FIRST_NAME_LISTS: PackedStringArray = ["feminine", "masculine", "neutral"]

var terrains: Array[TerrainDef] = []
var needs: Array[NeedDef] = []
var districts: Dictionary[String, DistrictDef] = {}
## District ids in the order they are stamped into the world.
var district_order: Array[String] = []
var start_district: String = ""
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
	WorldLoader.load(self, reader, root.path_join("world"))
	for problem: String in reader.errors:
		errors.append(problem)


func is_valid() -> bool:
	return errors.is_empty()


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
