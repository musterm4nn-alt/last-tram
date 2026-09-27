---
id: T-0003
title: Grid pathfinding (single level, surface costs)
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0001]
builder:
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
Change: `data/terrain.json` + `sim/content/terrain_def.gd` + `ContentDB` (new `path_cost`
field); `sim/sim.gd` (add `nav`).
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

## Questions

## Review feedback
