---
id: T-0084
title: Same-view screenshots for the art gate
status: todo
milestone: Art
size: S
owner: builder
depends_on: [T-0080, T-0083]
builder:
review_rounds: 0
---

## Goal
One command shoots the art gate's scene (the Altmarkt and Haus 12) at noon and at 22:00 from
exactly the same camera, for any art set, so the routes can be compared side by side.

## Read first
`tools/screenshot.sh`, `game/launch_options.gd`, `game/main.gd`, `game/view2d/camera_rig_2d.gd`.

## Scope
- New: `tools/art_shots.sh`.
- Change: `launch_options.gd`, `main.gd` (`--look-at`, `--hide-hud`), `camera_rig_2d.gd`
  (a `look_at_cell(cell: Vector2i)` that turns command mode on and centres the camera),
  `tests/game/test_launch_options.gd`, `AGENTS.md`'s command table (one line: this ticket
  may edit it).
- **Out of scope:** the comparison page (Opus makes it as an Artifact), video.

## Specification
- `--look-at=X,Y`: after the quick start, command mode on and the camera centred on cell
  (X, Y) (clamped to the town as usual).
- `--hide-hud`: the HUD, minimap and clock are hidden (only the world is drawn).
- `tools/art_shots.sh <set> [out_dir]` runs `tools/screenshot.sh` four times, into
  `out/art/<set>/`: `noon.png` and `night.png` at `--look-at=40,26 --zoom=2`, and
  `noon-close.png` and `night-close.png` at `--look-at=52,28 --zoom=3`, each with
  `--art=<set> --hide-hud --seed=1`, noon by `--advance` from the start time to 12:00 and
  night to 22:00 (work the minutes out from the new-game start time; print them).

## Acceptance criteria
- [ ] `--look-at` and `--hide-hud` parse, and `--look-at` skips the menu →
  `test_launch_options.gd: test_look_at_and_hide_hud`
- [ ] `CameraRig2D.look_at_cell` puts the camera at the cell's centre (clamped) →
  `test_command_mode.gd: test_look_at_cell`
- [ ] `tools/art_shots.sh placeholder` writes four PNGs that show the same framing; open them
  and check

## Implementation notes

## Questions

## Review feedback
