---
id: T-0089
title: Corner faces stop at the side wall
status: done
milestone: Art
size: S
owner: builder
depends_on: [T-0087, T-0088]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The owner's look at route B (4 October): where a room's top wall (a full-width face) meets a
side wall (a thin line), the face's tile is a whole cell wide and stuck out past the side
wall onto the street, at all four outer corners and junctions of the flat.

## Scope
`game/view2d/wall_shapes.gd`, `wall_layer_2d.gd`, `world_view_2d.gd`, `interior_dim_2d.gd`,
`tests/game/test_wall_shapes.gd`. **Out of scope:** the wall tiles themselves, roofs.

## Specification
- `WallShapes.face_trim(grid, cell) -> int`: for a FACE cell whose south neighbour is THIN or a
  DOORWAY, `ARM_W` and/or `ARM_E` for each side with no wall, window or door beside it; else 0.
- `WallLayer2D.add_trim(cell, sides, east, west)`: draws the neighbour's ground over the face's
  columns outside the thin wall's edge (`[0, BAND_FROM - 1)` west, `[BAND_FROM + BAND + 1, 16)`
  east). `WorldView2D` adds one for every trimmed face.
- `InteriorDim2D` darkens a trimmed strip when the cell beside it is outside the open building.

## Acceptance criteria
- [x] Corners and junctions trim only their open side → `test_wall_shapes.gd: test_face_trim_at_corners`
- [x] Screenshot `out/t0089.png` (a plain launch, zoom 2): the top walls and the middle wall
  end flush with the side walls; the trimmed strips are dark like the street around them

## Implementation notes
Built by the architect from the owner's marked-up screenshot. The face is not redrawn: the
ground beside it is painted over its outer 4 px (above the tile layer, under objects), so
any art set's wall tile works. A poster drawn near a wall tile's edge can be cut at a corner;
art can avoid that. `tools/check.sh` passes.
