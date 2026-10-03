---
id: T-0087
title: Wall corners carry the face; the wheel doesn't zoom over panels
status: done
milestone: Art
size: S
owner: builder
depends_on: [T-0085]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Two things from the owner's playtest (3 October): (1) where a room's top wall meets a side
wall (a corner, or a T-junction between two rooms) a thin wall stub poked out of the middle
of the wall face; (2) scrolling the phone (or any list) past its end zoomed the town.

## Scope
`game/view2d/wall_shapes.gd`, `game/view2d/camera_rig_2d.gd`, their tests. **Out of
scope:** everything else.

## Specification
- `WallShapes.kind`: a wall (not a window) with a wall or door below it is FACE when its east
  or west neighbour faces a room (`_faces_room`): corners and junctions in a top wall carry
  the face on, and the side wall's thin line starts under it. A window there stays THIN
  (it belongs to its side wall).
- `CameraRig2D.wheel_over_ui(event, hovered) -> bool`: a mouse-wheel event while the mouse is
  over any Control (`Viewport.gui_get_hovered_control()`) is not zoom. Keyboard zoom (+/-) is
  unchanged.

## Acceptance criteria
- [x] Corners in a top wall are FACE, bottom corners stay THIN →
  `test_wall_shapes.gd: test_kinds_in_a_room`
- [x] The wheel over a panel doesn't zoom → `test_command_mode.gd: test_wheel_over_a_panel_does_not_zoom`
- [x] Screenshot `out/corner.png` (the flat at zoom 4): the top walls run cleanly into the
  corners and the junction between the hall and the kitchen

## Implementation notes
Built and reviewed by the architect as a direct playtest fix. The first version also made a
window at a junction FACE (the bathroom's west window turned into a front window sticking
out of the side wall); windows are excluded. `tools/check.sh` → 720 passed.

## Questions

## Review feedback
