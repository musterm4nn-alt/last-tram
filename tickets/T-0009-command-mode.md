---
id: T-0009
title: Command mode: Tab toggle, free camera, click the ground to walk
status: draft
milestone: M1
size: M
owner: builder
depends_on: [T-0004]
builder:
review_rounds: 0
---

## Goal
Tab switches between direct mode (WASD walks, camera follows) and command mode (WASD/drag pans the camera, click the ground to walk there with WalkToCommand).

## Notes for the architect (to detail before this becomes todo)
- A small control-mode state in game/ (not sim): where does it live? Probably `game/input/control_mode.gd` referenced by PlayerController and CameraRig2D.
- Mouse → cell conversion helper in view2d (camera transform ÷ TILE_PX).
- HUD shows the mode; hint line updates.
- Headless-testable part: the cell-conversion function. Screenshot for the rest.

## Implementation notes

## Questions

## Review feedback
