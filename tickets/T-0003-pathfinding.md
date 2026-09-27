---
id: T-0003
title: Grid pathfinding (single level, surface costs)
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0001]
builder: OpenCode / Muse Spark
review_rounds: 0
---

## Goal
The sim can find walking routes between cells, around walls and objects, preferring
pavements to roads. This is the basis for click-to-walk (T-0004) and for walking to objects
(T-0007).

## Read first
- `docs/design/world-and-map.md` → "Navigation (M1+)"
- `docs/architecture.md` → "State: World and entities" (derived caches, `revision`)
- Godot class reference for `AStarGrid2D` (use it: it's a `RefCounted` engine class, allowed in
  `sim/`)

## Scope
Create `sim/world/pathfinder.gd` (`Pathfinder`) and `tests/sim/test_pathfinding.gd`.
Change: `data/terrain.json` + `sim/content/terrain_def.gd` + `sim/content/terrain_loader.gd`
(read and validate the new `path_cost` field, next to the other terrain fields);
`sim/sim.gd` (add `nav`). T-0001 as merged: `grid.is_walkable()` is false on cells covered
by a blocking object, and adding or removing an object bumps `grid.revision`.
**Out of scope:** following paths (T-0004), multiple levels and stairs (M2), private lots.

## Specification
- Terrain gets `"path_cost"` (float ≥ 1.0, required, validated). Values: floors, doors,
  sidewalk, cobblestone, bridge, crossing = 1.0; grass = 1.5; road, tram_track = 4.0;
  non-walkable terrains = 1.0 (unused).
- `Pathfinder` (RefCounted):
  ```gdscript
  func _init(p_world: World) -> void
  ## Cells to walk through after `from`, ending with `to`. Empty if unreachable, if `to` or
  ## `from` is not walkable, if from == to, or if they are on different levels.
  func find_path(from: Vector3i, to: Vector3i) -> Array[Vector3i]
  func is_reachable(from: Vector3i, to: Vector3i) -> bool
  ```
- Internals: one `AStarGrid2D` per level, region = the grid, `cell_size = Vector2(1, 1)`,
  `diagonal_mode = DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` (no corner cutting),
  `default_compute_heuristic` and `default_estimate_heuristic` = `HEURISTIC_OCTILE`. Cell
  solid = `not world.grid.is_walkable(cell)`; weight = terrain `path_cost`.
  **Lazy rebuild:** remember the `grid.revision` each level was built at, and rebuild that
  level before a query if the revision changed. A derived cache: never saved.
- `Sim` gets `var nav: Pathfinder`, created in `_init` (not saved; it rebuilds itself).

## Acceptance criteria (all in `tests/sim/test_pathfinding.gd`, built with `SimFactory.from_rows`)
- [ ] A straight corridor gives the straight path, ending at the target, excluding the start.
- [ ] A wall between start and goal gives a path around it; every cell in it is walkable and
  consecutive cells are neighbours (including diagonals).
- [ ] No corner cutting: a diagonal step never passes between two blocked cells or next to a
  blocked corner.
- [ ] Unreachable goal, goal in a wall, from == to, and different levels all give an empty path.
- [ ] Surface cost: with a road shortcut and a longer pavement detour, the path takes the
  pavement.
- [ ] Placing an object (T-0001) across the corridor changes the next path (lazy rebuild via
  `revision`), and removing it restores the short path.
- [ ] On the real Altstadt map, a path from the player's spawn to the Späti door exists.
  Report its length and the time taken (measured once) in your notes.
- [ ] `tools/check.sh` passes; content validation rejects a missing or < 1 `path_cost`.

## Implementation notes
- `Pathfinder` (`sim/world/pathfinder.gd`, RefCounted): one `AStarGrid2D` per level,
  region = grid bounds, `cell_size` (1,1), `DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`,
  octile heuristics; solid = `not grid.is_walkable()`, weight = terrain `path_cost`.
  Lazy rebuild per level when `grid.revision` changed. `find_path` drops the start
  cell (`get_id_path` includes it). `is_reachable` is `not find_path().is_empty()`,
  except from == to counts as reached when the cell is walkable (standing there).
- `Sim` owns `var nav: Pathfinder`, built in `_init` from its world; never saved
  (`SaveCodec` only stores clock/rng/world/pending, and `from_dict` builds a new
  `Sim`, so `nav` always matches the loaded world).
- `path_cost` added to `data/terrain.json` exactly per spec (floors/doors/sidewalk/
  cobblestone/bridge/crossing 1.0; grass 1.5; road/tram_track 4.0; non-walkable 1.0),
  `TerrainDef.path_cost` (default 1.0), loader reads it and errors when < 1.0
  (a missing key also trips `read_num`'s "must be a number" plus this error).
- Tests (`tests/sim/test_pathfinding.gd`, 12 tests) cover every acceptance criterion;
  `tests/fixtures/terrain_bad_cost.json` is a minimal terrain file with one 0.5-cost
  entry for the < 1 rejection test (existing `content_broken/terrain.json` covers
  the missing-key case). Road test: the pavement detour is the same step count as
  the road (diagonals) but ~3x cheaper, so the assertion is "zero road cells".
- Verified: `tools/check.sh` → 137 passed, 0 failed (was 125 before; +12 new).
- Altstadt (seed 1): spawn (50,26,0) → Späti north door (5,23,0): path length 50 cells,
  cold query incl. full 72×44 graph build ~3.1 ms, warm query ~16 µs (M3 Pro, headless,
  measured once each). Return trip also 50 cells.
- Uncertain / left out: nothing in scope left out. `is_reachable(from, from)` returns
  true on walkable ground by my choice (spec only defined `find_path` for that case);
  reviewer may prefer false — one-line change either way.

## Questions

## Review feedback

**Round 1 (architect): passed with no changes to behaviour.** Built from the latest `main`;
the code follows the spec closely and the notes are honest and precise.
- Tests are real: a mutation check broke five things one at a time (corner cutting allowed,
  no surface weights, never rebuilding, keeping the start cell, no minimum cost) and each one
  made at least one test fail.
- Reviewer's own measurement agrees with the notes: spawn (50,26) to the Späti door (5,23)
  is 50 cells, all on floor and pavement (no road), cold ~3.0 ms including the 72x44 graph
  build, warm ~17 µs.
- `is_reachable(from, from)` returning true on walkable ground is the right call (a person
  already standing somewhere has reached it). Later tickets may rely on it.
- Reviewer tidy-up: two redundant casts removed in `_grid_for` (the dictionaries are typed).
  Docs updated for `path_cost` and `sim.nav` (cookbook terrain recipe, world-and-map,
  architecture folder map).
- For later (not this ticket): every grid change rebuilds the whole level's graph on the next
  query. Fine at 72x44 (~3 ms); a much bigger map or build mode may want per-cell updates.
