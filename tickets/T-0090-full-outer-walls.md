---
id: T-0090
title: Outer walls show at full thickness indoors
status: done
milestone: Art
size: S
owner: builder
depends_on: [T-0086, T-0089]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The owner (4 October): indoors, the building's outer walls looked half as thick as inner
walls, because the darkened street covered each outer wall cell's whole outer half, wall
band included. Darken only the ground beside the wall.

## Scope
`game/view2d/interior_dim_2d.gd`, `tests/game/test_interior_dim.gd`. **Out of scope:** how
walls are drawn.

## Specification
- `InteriorDim2D.ground_rects(arms, quadrant) -> Array[Rect2i]`: the 4-px blocks of a thin wall
  or doorway cell's quadrant that are ground: not the band's middle 8 px or its arms toward
  walled neighbours, and, under an east-west run, not the 2-px face below the band.
- `_draw` darkens those rects (instead of the whole quadrant) where the quadrant's ground is
  outside the open building.

## Acceptance criteria
- [x] West wall, corner, bottom wall: only ground is darkened → `test_interior_dim.gd`
  (`test_a_west_wall_keeps_its_band`, `test_a_corner_keeps_its_arms`, `test_a_bottom_wall_keeps_its_face`)
- [x] The blocks match WallLayer2D's band → `test_the_band_matches_the_wall_layer`
- [x] Screenshots `out/t0090.png` and `out/t0090-low.png` (in the flat, zoom 2): outer walls
  as thick as inner walls, the street beside them dark

## Implementation notes
Built by the architect from the owner's report. Before/after: `out/t0090-pair.png`.
`tools/check.sh` passes.
