class_name DistrictDef
extends RefCounted
## A hand-made part of town, authored in data/world/districts/<id>/:
##   district.json  - name, origin, spawn, places, level files
##   level_<n>.txt  - ASCII map of floor n (glyphs from data/terrain.json)
## The world is the union of all districts, each placed at its origin.

var id: String = ""
var name: String = ""
## Top-left corner of this district in world cells.
var origin: Vector2i = Vector2i.ZERO
## Width/height in cells (from the ASCII rows).
var size: Vector2i = Vector2i.ZERO
## Floor level -> ASCII rows (all rows have length size.x).
var levels: Dictionary[int, PackedStringArray] = {}
## Where a new player starts, in WORLD cells.
var player_spawn: Vector3i = Vector3i.ZERO
var places: Array[PlaceDef] = []
## Authored object placements (from the district's optional objects.json).
var objects: Array[ObjectPlacement] = []
