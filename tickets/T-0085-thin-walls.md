---
id: T-0085
title: Walls drawn by direction (thin walls, side windows)
status: done
milestone: Art
size: M
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Walls stop looking a whole tile thick. The wall along the top of a room shows its face (the
plaster, a window, a front door), as a 3/4 view should; every other wall is drawn as a thin
line with floor or pavement beside it, and a window in a side wall is drawn edge-on as a
strip of glass in that line. The owner asked for this on 3 October ("I really dislike how
thick the walls are, and the windows facing left or right don't look right"). View only:
walls still fill their cell in the sim.

## Read first
`game/view2d/world_view_2d.gd`, `placeholder_tiles.gd`, `art_set.gd`, `data/terrain.json`
(`surface`, `indoor`).

## Scope
- New: `game/view2d/wall_shapes.gd` (`WallShapes`, pure static functions),
  `game/view2d/wall_layer_2d.gd` (`WallLayer2D`), `tests/game/test_wall_shapes.gd`.
- Change: `world_view_2d.gd` (thin cells are left out of the TileMapLayer and drawn by a
  `WallLayer2D` per floor), `art_set.gd` (optional `"thin_walls"` colours),
  `data/art2d/README.md`, `docs/art.md`.
- **Out of scope:** roofs and hiding interiors (T-0086), the town map and minimap, the sim.

## Specification
**`WallShapes`** (`const FACE := 1, THIN := 2, DOORWAY := 3`, `NONE := 0`):
- `static func kind(grid: WorldGrid, cell: Vector3i) -> int`
  - a `surface == "wall"` cell (wall, window) is FACE when the cell south of it is indoor and
    not a door (a room below sees its face); a wall with no indoor cell among its 8
    neighbours (a free-standing wall) is FACE when its south neighbour is not a wall; every
    other wall is THIN.
  - a door is FACE when its east or west neighbour is a FACE wall (a door in the top wall
    of a room), else DOORWAY.
  - anything else is NONE.
- `static func arms(grid: WorldGrid, cell: Vector3i) -> int` — bitmask N 1, E 2, S 4, W 8 of
  the 4 neighbours that are walls, windows or doors.
- `static func quadrant_ground(grid: WorldGrid, cell: Vector3i, quadrant: int) -> Vector3i`
  — the cell whose ground fills quadrant 0 NW, 1 NE, 2 SW, 3 SE of a THIN or DOORWAY cell:
  the first of (horizontal neighbour, vertical neighbour, diagonal) on that side that is not
  a wall, window or door; the cell itself if none is.

**`WallLayer2D`** (Node2D, one per floor, drawn above that floor's TileMapLayer): for each
THIN or DOORWAY cell draws the four ground quadrants (8×8 regions of the ground cells'
tiles, from the art set or the placeholder), then a 6-px wall band through the middle of
the cell with arms to each neighbour in `arms` (1-px darker edge, a lighter top), a 2-px
face strip under horizontal parts, glass along the band for windows, and short jambs and a
wooden threshold for doorways. Colours: the art set's `"thin_walls"` (`top`, `edge`,
`face`, `glass`), else derived from the wall tile's average colour (placeholder: the wall's
`debug_color`).

## Acceptance criteria
- [x] Top walls of a room are FACE, side and bottom walls THIN, a free-standing wall FACE →
  `test_wall_shapes.gd: test_kinds_in_a_room`
- [x] Doors in a top wall are FACE, in side and bottom walls DOORWAY → `test_door_kinds`
- [x] Arms follow the neighbouring walls, windows and doors → `test_arms`
- [x] Quadrants take the ground on their own side (floor inside, pavement outside, the
  diagonal in a corner) → `test_quadrant_ground`
- [x] `--art` sets still load; `"thin_walls"` colours are validated →
  `test_art_set.gd: test_thin_wall_colours`
- [x] Screenshot of the flat (placeholders, and with a route's art set on its branch):
  side walls are thin lines, the side windows are glass strips, the top walls show faces

## Implementation notes
- `game/view2d/wall_shapes.gd` (`WallShapes`): `kind`, `arms`, `quadrant_ground` as specified.
- `game/view2d/wall_layer_2d.gd` (`WallLayer2D`): draws the quadrants, the band (edge,
  top, a 2-px face under east-west runs), glass and doorways. Glass follows the straight run
  at a T-junction (`runs_across`): the first screenshot showed the bathroom's west window
  with sideways glass where the bathroom wall joins it.
- `WorldView2D.rebuild` leaves THIN and DOORWAY cells out of the TileMapLayer and fills a
  `WallLayer2D` per floor (visible with its floor). Colours: `WallLayer2D.colors_for` from the
  wall tile's average colour (placeholder: `debug_color`), overridden by the art set's
  `thin_walls`.
- `ArtSet.thin_walls` (validated: known keys, `#rrggbb`); fixtures extended (the bad set now
  has nine mistakes).

Verified: `tools/check.sh` → 711 passed (new `test_wall_shapes.gd` ×5,
`test_thin_wall_colours`). Screenshots: `out/t0085-b.png` (the flat, placeholders),
`out/t0085-wide.png` (the Hauptstraße: the north buildings' bottom walls are thin lines with
glass), and `out/t0085-custom.png` / `out/t0085-chatgpt.png` with routes B and C's art sets
copied in from their branches for the shot (not committed): ochre thin walls, faces on the top
walls only.

## Questions

## Review feedback
