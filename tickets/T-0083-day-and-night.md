---
id: T-0083
title: Day and night in the 2D view
status: done
milestone: Art
size: M
owner: builder
depends_on: [T-0082]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The town gets darker and bluer in the evening and brighter in the morning. At night the
street lamps throw warm sodium-orange pools of light, some windows glow, and the insides of
buildings stay lit, so you can still see your flat. It is view only: nothing in the sim
changes.

## Read first
`docs/art.md` ("The look we're aiming for"), `game/view2d/world_view_2d.gd`,
`sim/core/sim_clock.gd` (`minute_of_day`).

## Scope
- New: `game/view2d/day_night.gd` (`DayNight`, pure static functions),
  `game/view2d/night_lights_2d.gd` (`NightLights2D`), `tests/game/test_day_night.gd`.
- Change: `main.gd` (add the nodes), `docs/art.md` (a line on how night is drawn).
- **Out of scope:** weather, seasons, lights you can switch, lit windows that follow who is
  home (later), the minimap and the town map (they stay untinted).

## Specification
**`class_name DayNight extends RefCounted`**
- `static func tint(minute_of_day: int) -> Color` — the world's `CanvasModulate` colour.
  Keyframes, linear in between (wrapping at midnight): 05:00 night, 07:00 day, 18:00 day,
  19:30 dusk, 21:00 night. Day `Color(1, 1, 1)`, dusk `Color(0.86, 0.72, 0.70)`, night
  `Color(0.30, 0.34, 0.52)`.
- `static func darkness(minute_of_day: int) -> float` — 0 by day, 1 at night, along the same
  keyframes (dusk 0.5); lights scale with it.
- `static func window_lit(cell: Vector2i, minute_of_day: int) -> bool` — a fixed hash of the
  cell against a share that falls through the night: 70 % from 18:00 to 23:00, 30 % to
  01:00, 5 % to 05:00, 30 % to 07:00, 0 by day.
- `static func light_map(grid: WorldGrid, level: int, lamp_cells: Array[Vector2i], minute_of_day: int) -> Image`
  — `LIGHT_PX` (4) pixels per cell, white = full light: every indoor terrain cell is full;
  each lamp adds a soft disc of radius 3.5 cells; each lit window adds a disc of radius 1.5
  cells centred on the window cell. Values are clamped to 1.

**`class_name NightLights2D extends Node2D`** (added in `main.gd` after the depth node)
- Owns a `CanvasModulate` (colour from `tint`) and one `PointLight2D` whose texture is the
  light map (`texture_scale` so one map pixel covers `TILE_PX / LIGHT_PX` world pixels),
  colour sodium orange `#ffb35c`, energy `darkness * 1.0`, blend mode add. One map and one
  light cover lamps, windows and interiors (interiors get the same warm colour). Rebuild the
  map when the viewed level changes, the grid revision changes, or every 10 game minutes;
  hide the light when `darkness` is 0.
- Lamp cells: `street_lamp` objects on the viewed level (by tag).

## Acceptance criteria
- [x] `tint` is white at 12:00, the night colour at 23:00 and 03:00, in between at 20:00, and
  continuous across midnight → `test_day_night.gd: test_tint_keyframes`
- [x] `darkness` is 0 at noon, 1 at midnight → `test_darkness`
- [x] `window_lit` is stable for a cell and minute, about 70 % at 21:00 over 1000 cells,
  0 % at noon → `test_window_share`
- [x] The light map is bright at a lamp cell and at an indoor cell, dark on the square far
  from lamps → `test_light_map` (a small hand-built grid)
- [x] Screenshots: the Altmarkt at noon and at 22:00 (`out/t0083-noon.png`,
  `out/t0083-night.png`, with `--advance` and `--command`); open them and check the night
  one is dark blue with orange pools around the lamps and lit rooms

## Implementation notes
- `game/view2d/day_night.gd` (`DayNight`): `tint`, `darkness`, `window_share`,
  `window_lit`, `light_map`, all pure. Keyframes as specified, except **dusk darkness is
  0.35** (0.5 made lit rooms glow orange at 19:30).
- Changed while tuning by eye: the light map holds **colours** and the light is white, so
  interiors get a warm white (`INDOOR_LIGHT`), lamps sodium orange (`LAMP_LIGHT`, radius 3.5
  cells), windows a softer amber (radius 1.5). With one orange light, rooms turned bright
  orange. Lamp and window light only lands on outdoor cells; it used to shine through walls
  and leave hot spots in the rooms.
- `game/view2d/night_lights_2d.gd` (`NightLights2D`, added in `main.gd` after the depth
  layer): a `CanvasModulate` and one `PointLight2D` (additive, `texture_scale` 4, centred on
  the town). The map is rebuilt only when the floor, the grid revision, the window share or
  the game changes (the window hash is fixed, so the map changes about five times a day).
  The HUD, minimap and bubbles are CanvasLayers and stay untinted.
- `docs/art.md`: a paragraph on how night is drawn.

Verified: `tools/check.sh` → 703 passed (new `tests/game/test_day_night.gd` ×5).
Screenshots (zoom 2, command mode): `out/t0083-noon.png` (17:01, see below: untinted),
`out/t0083-dusk.png` (19:40: warm dusk, lamps coming on), `out/t0083-night.png` (22:00:
dark blue streets, orange pools under every lamp, lit rooms, a few glowing windows).

Found for T-0084: `--advance=240` from the 08:00 start ended at 17:01, because the default
character's work shift is skipped as one block. The art shots must reach noon another way.

## Questions

## Review feedback
