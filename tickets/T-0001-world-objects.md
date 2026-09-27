---
id: T-0001
title: World objects in the sim (data, placement, blocking, saving)
status: todo
milestone: M1
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
The town can contain **objects** (fridge, bed, sofa...) defined in data, placed in districts,
blocking movement, and saved with the game. They aren't drawn yet (T-0002) and can't be used
yet (T-0006).

## Read first
- `AGENTS.md`, `docs/conventions.md`, `docs/cookbook.md` ("Add a new kind of content",
  "Add a field to Person (or any saved entity)")
- `docs/design/world-and-map.md` → "Objects (M1)"
- Code to copy patterns from: `sim/content/content_db.gd` (loading and validation),
  `sim/content/terrain_def.gd`, `sim/world/world.gd`, `sim/world/world_grid.gd`,
  `sim/people/person.gd` (to_dict/from_dict)

## Scope
Create:
- `sim/content/object_def.gd`, `sim/content/use_slot_def.gd`, `sim/content/object_placement.gd`
- `sim/world/world_object.gd`
- `data/objects/furniture.json`
- `data/world/districts/altstadt/objects.json`
- `tests/sim/test_objects.gd`
- `tests/fixtures/content_broken/objects/` broken examples, plus extra assertions in
  `tests/sim/test_content.gd`

Change:
- `sim/content/content_db.gd` (load objects and district object placements; validate)
- `sim/content/district_def.gd` (add `objects`)
- `sim/world/world_grid.gd` (object blockers)
- `sim/world/world.gd` (objects collection, add/remove/query, save)
- `sim/sim_factory.gd` (place district objects in `new_game`)

**Out of scope:** drawing objects (T-0002), using them (T-0006), pathfinding (T-0003),
build mode.

## Specification

### Rule: all objects block movement (for now)
People use an object from one of its **use slots**: walkable cells *next to* the object where
they stand, facing it. (The view may later draw a person *on* the sofa while sitting; the sim
position stays on the slot.) `blocks_movement` still exists in data for later non-blocking
objects (rugs), but every M1 object sets it to `true`.

### Data: `data/objects/furniture.json`
```json
{
	"_doc": "...explain the fields...",
	"objects": [
		{
			"id": "fridge",
			"name": "Fridge",
			"size": [1, 1],
			"blocks_movement": true,
			"blocks_sight": false,
			"tags": ["fridge"],
			"use_slots": [ { "offset": [0, 1], "facing": [0, -1] } ],
			"price": 45000,
			"debug_color": "#dfe6e9"
		}
	]
}
```
- `size` = [width, height] in cells at rotation 0. Footprint = offsets (0..w-1, 0..h-1) from
  the origin (top-left).
- `use_slots[].offset` is relative to the origin at rotation 0 and may lie outside the
  footprint; `facing` is the direction the person looks while using it (a unit cardinal
  vector).
- `price` is in euro **cents** (int).
- Load **every** `.json` file in `data/objects/` (sorted by name), all with the same
  format. Create `furniture.json` with these four objects (you choose sensible slots and
  colours):
  `fridge` (1×1, slot below), `bed_double` (2×2, slots left and right of the upper cell),
  `sofa` (2×1, slots below both cells), `tv` (1×1, slot two cells below, facing up).

### Classes
```gdscript
class_name UseSlotDef extends RefCounted
var offset: Vector2i
var facing: Vector2i

class_name ObjectDef extends RefCounted
var id: String; var name: String; var size: Vector2i
var blocks_movement: bool; var blocks_sight: bool
var tags: PackedStringArray; var use_slots: Array[UseSlotDef]
var price: int; var debug_color: Color
func footprint(rotation: int) -> Array[Vector2i]   # rotated local offsets
static func rotate_offset(offset: Vector2i, size: Vector2i, rotation: int) -> Vector2i
static func rotate_facing(facing: Vector2i, rotation: int) -> Vector2i

class_name ObjectPlacement extends RefCounted     # authored placement (content)
var def_id: String; var cell: Vector3i            # WORLD coordinates (district origin applied)
var rotation: int                                  # 0..3

class_name WorldObject extends RefCounted          # runtime entity (saved)
var id: int; var def_id: String; var origin: Vector3i; var rotation: int
func cells(content: ContentDB) -> Array[Vector3i]        # footprint cells in the world
func slot_count(content: ContentDB) -> int
func slot_cell(content: ContentDB, index: int) -> Vector3i
func slot_facing(content: ContentDB, index: int) -> Vector2i
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> WorldObject
```

### Rotation (exact; clockwise quarter turns, w/h = size at rotation 0)
| rotation | offset (dx, dy) becomes | facing (fx, fy) becomes |
|---|---|---|
| 0 | (dx, dy) | (fx, fy) |
| 1 | (h−1−dy, dx) | (−fy, fx) |
| 2 | (w−1−dx, h−1−dy) | (−fx, −fy) |
| 3 | (dy, w−1−dx) | (fy, −fx) |

Example: a 1×1 fridge with slot (0, 1) facing (0, −1) at rotation 1 has its slot at (−1, 0)
facing (1, 0), which is to its left, looking right.

### ContentDB
- `var objects: Dictionary[String, ObjectDef]`, `func object_def(id: String) -> ObjectDef`
  (null if unknown).
- `_load_objects(dir)` is called from `load_from()` **before** `_load_world()`. Validate:
  unique id, size ≥ 1×1, at least one use slot, facing is a unit cardinal vector,
  price ≥ 0, valid colour, `tags` is a list of strings.
- `DistrictDef.objects: Array[ObjectPlacement]` loaded from the district's optional
  `objects.json` (`{"objects": [{"def": "fridge", "cell": [x, y, level], "rotation": 0}]}`,
  local coordinates). Validate: known def; rotation 0..3; every footprint cell is inside the
  district and on walkable terrain (glyph lookup in that level's rows); no two placements
  overlap; at least one use slot cell is walkable and not covered by another placement.
  Error messages name the file, the object and the problem.

### WorldGrid: object blockers (derived, never saved)
- A per-level `PackedByteArray` of blocker counts.
- `func add_object_blocker(c: Vector3i) -> void` and `func remove_object_blocker(c: Vector3i) -> void`
  (bump `revision`).
- `is_walkable(c)` = terrain walkable **and** no blocker. Keep `_walkable` terrain-only and
  check blockers separately.

### World
- `var objects: Dictionary[int, WorldObject] = {}`
- `func can_place(def_id: String, origin: Vector3i, rotation: int) -> String`: "" if OK,
  otherwise a reason ("unknown object", "outside the map", "blocked terrain", "overlaps
  object 12").
- `func add_object(obj: WorldObject) -> bool`: false (and no change) if `can_place` fails;
  otherwise store it, add blockers (if `blocks_movement`), update the cell index, and emit
  nothing (World has no events; the caller emits).
- `func remove_object(id: int) -> void`, `func get_object(id: int) -> WorldObject`,
  `func objects_at(cell: Vector3i) -> Array[int]` (via a derived `Dictionary[Vector3i, Array]`
  index, rebuilt on load).
- Save: `to_dict()` adds `"objects": [...]`; `from_dict()` reads `d.get("objects", [])` (old
  saves have none, so **no** save-version bump is needed) and re-adds each object so blockers
  and the index are rebuilt. Objects whose def id is unknown (for example from a content pack
  that was removed later) are **skipped without logging errors**.

### SimFactory
`new_game()` places every district's objects after stamping terrain (ids from
`world.new_id()`), and emits `&"object_added"` with `{"object_id": id}` for each.

### Altstadt
`data/world/districts/altstadt/objects.json` places in the player's flat (Haus 12, see
`level_0.txt`): the fridge in the kitchen, `bed_double` in the bedroom, and `sofa` and `tv`
in the living room. Keep door cells and their neighbours free.

## Acceptance criteria
- [ ] Real content loads with zero errors → `test_content.gd::test_game_content_is_valid`
- [ ] Broken object data is reported (unknown def, overlap, in a wall, bad rotation, no
  slots) → new test in `test_content.gd` using `tests/fixtures/content_broken/`
- [ ] Rotation math matches the table for all 4 rotations, both offsets and facings →
  `test_objects.gd::test_rotation_*`
- [ ] A blocking object stops movement: walking into a placed fridge stops before it, and
  after `remove_object` you can walk through → `test_objects.gd`
- [ ] `can_place` rejects overlaps, walls and out-of-bounds cells with a reason →
  `test_objects.gd`
- [ ] New game has all Altstadt objects placed (count equals the placements in content) →
  `test_objects.gd`
- [ ] Objects survive save/load, and "save mid-run equals uninterrupted run" still passes with
  objects present → `test_objects.gd` + existing `test_save.gd`
- [ ] The old fixture `tests/fixtures/saves/v1_basic.json` still loads (no objects) → existing
  test
- [ ] A save containing an object with an unknown def id loads, skips that object, and logs no
  errors → `test_objects.gd`
- [ ] `tools/check.sh` passes

## Implementation notes

## Questions

## Review feedback
