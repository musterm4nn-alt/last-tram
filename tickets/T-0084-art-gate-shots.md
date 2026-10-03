---
id: T-0084
title: Same-view screenshots for the art gate
status: done
milestone: Art
size: S
owner: builder
depends_on: [T-0080, T-0083]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
One command shoots the art gate's scene (the Altmarkt and Haus 12) at noon and at 22:00 from
exactly the same camera, for any art set, so the routes can be compared side by side.

## Read first
`tools/screenshot.sh`, `game/launch_options.gd`, `game/main.gd`, `game/view2d/camera_rig_2d.gd`.

## Scope
- New: `tools/art_shots.sh`.
- Change: `launch_options.gd`, `main.gd` (`--look-at`, `--hide-hud`, `--paused`), `camera_rig_2d.gd`
  (a `look_at_cell(cell: Vector2i)` that turns command mode on and centres the camera),
  `tests/game/test_launch_options.gd`, `AGENTS.md`'s command table (one line: this ticket
  may edit it).
- **Out of scope:** the comparison page (Opus makes it as an Artifact), video.

## Specification
- `--look-at=X,Y`: after the quick start, command mode on and the camera centred on cell
  (X, Y) (clamped to the town as usual).
- `--hide-hud`: the HUD, minimap and clock are hidden (only the world is drawn).
- `--paused`: start paused (added while building, see the notes).
- `tools/art_shots.sh <set> [out_dir]` runs `tools/screenshot.sh` four times, into
  `out/art/<set>/`: `noon.png` and `night.png` at `--look-at=40,26` and 2× zoom
  (`--zoom=1`, an index), and `noon-close.png` and `night-close.png` at `--look-at=52,28`
  and 3× (`--zoom=2`), each with `--art=<set> --hide-hud --paused --seed=1`, noon by `--advance` from the start time to 12:00 and
  night to 22:00 (work the minutes out from the new-game start time; print them).

## Acceptance criteria
- [x] `--look-at` and `--hide-hud` parse, and `--look-at` skips the menu →
  `test_launch_options.gd: test_look_at_and_hide_hud`
- [x] `CameraRig2D.look_at_cell` puts the camera at the cell's centre (clamped) →
  `test_command_mode.gd: test_look_at_cell`
- [x] `tools/art_shots.sh placeholder` writes four PNGs that show the same framing; open them
  and check

## Implementation notes
- `CameraRig2D.look_at_cell(cell)` (command mode on, camera on the cell, smoothing reset) and
  the pure `CameraRig2D.cell_centre(cell, grid)`.
- `LaunchOptions`: `look_at` (skips the menu), `hide_hud`, and **`paused`**, which the ticket
  didn't have: T-0083 found that `--advance=240` showed 17:01, because while the screenshot
  waits for its frames the player's work shift is time-skipped an hour per frame. Paused,
  the shot shows the advanced time exactly.
- `main.gd` applies them at the end of the quick start. It is now 338 lines (limit 350):
  the next launch option should move the option handling out into its own class.
- `tools/art_shots.sh <set> [out_dir]`: four shots; `--art` is passed only when
  `data/art2d/<set>.json` exists, so `placeholder` shoots the placeholders.
- `AGENTS.md`: one line in the command table (allowed by the ticket's scope).

Verified: `tools/check.sh` → 705 passed (new `test_look_at_and_hide_hud`,
`test_look_at_cell`). `tools/art_shots.sh placeholder` wrote `out/art/placeholder/`
`noon.png` (12:00: the whole Altmarkt and Haus 12, no HUD), `night.png`, `noon-close.png`
and `night-close.png` (Haus 12 lit inside, lamps glowing), the same framing each time.

## Questions

## Review feedback
