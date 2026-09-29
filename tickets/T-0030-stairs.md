---
id: T-0030
title: Stairs between floors (terrain, routes across levels, walking up and down)
status: todo
milestone: M2
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Buildings can have more than one floor. A stairs cell connects a floor with the one above,
routes can go up and down stairs, people walk along them and change floor, and the view shows
whichever floor the player is on.

## Read first
- `docs/design/world-and-map.md` → "Multiple floors (M2)", "Navigation (M1+)"
- As merged: `sim/world/pathfinder.gd` (`find_path` is empty across levels today),
  `sim/systems/movement_system.gd` (`follow_path`), `sim/world/world_grid.gd` (`levels()`,
  `has_level`), `data/terrain.json`, `game/session.gd` (`viewed_level`, set only on load)

## Scope
Change `data/terrain.json`, `sim/world/pathfinder.gd`, `sim/systems/movement_system.gd`,
`game/session.gd`, `tests/sim/test_pathfinding.gd` (the two different-level checks now need
"no stairs" setups), `game/view2d/placeholder_tiles.gd` (a stairs look). Create
`tests/sim/test_stairs.gd`. **Out of scope:** new district floors (T-0031), lots, command-mode
level paging (T-0031).

## Specification
- Terrain `stairs`: glyph `^`, name "Stairs", walkable, not sight-blocking, indoor,
  surface `floor`, `path_cost` 2.0, debug colour `#a38b6d`.
- **Stair link:** a stairs cell at (x, y, L) links to (x, y, L + 1) when that cell is also
  stairs; the link works both ways. A route may step from one end of a link to the other as
  one step (cost 2).
- `Pathfinder.find_path(from, to)` across levels: the same level works as before. Otherwise
  search over levels: a Dijkstra over nodes = stairs cells, where moving within a level
  between two cells costs the in-level A* path cost (use `AStarGrid2D`'s point path, summing
  weight × step length), and a link hop costs 2. Return the concatenated cell list (in-level
  segments plus the hop, which appears as the upper or lower stairs cell). Stairs cells per
  level are cached with the level's graph (same `revision` rule). Unreachable → `[]`.
- `MovementSystem.follow_path`: when the next waypoint's `z` differs from `person.level`
  (a hop: same x, y), set `person.level` to it, snap to its centre and pop it, spending 1.0 of
  the budget. Nothing else changes.
- `Session`: after stepping, set `viewed_level` to the player's level (the view already
  shows only `viewed_level`).
- Placeholder tiles: stairs draw as the floor colour with three darker horizontal bars.

## Acceptance criteria (`tests/sim/test_stairs.gd` unless named)
Build two-level worlds with `SimFactory.from_rows` for level 0 and `grid.ensure_level(1)` +
`grid.stamp_rows(1, ...)` for level 1.
- [ ] A path from level 0 to a room on level 1 goes through the stairs: every step is a
  neighbour on one level or a link hop, and it ends at the target.
- [ ] Without matching stairs above, level 1 is unreachable (`[]`), and `is_reachable` is
  false.
- [ ] Of two stairs, the route uses the cheaper one.
- [ ] Walking with `WalkToCommand` to level 1 ends there with `person.level == 1`, never
  overlapping a blocked cell on the level it is on.
- [ ] Save mid-climb, load, continue = uninterrupted run.
- [ ] `test_pathfinding.gd`'s different-level checks still pass (levels without stairs stay
  apart); content has no errors.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
