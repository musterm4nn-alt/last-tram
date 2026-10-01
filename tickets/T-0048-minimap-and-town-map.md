---
id: T-0048
title: Minimap and a full town map (M)
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0047]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
From the owner's M1 playtest: "add a map". It works like GTA. A small minimap sits in the
top-right corner, centred on you. Pressing M opens a full map of the district with every
place's name and a marker where you are. The full map pauses the game; M or Esc closes it.

## Read first
- `docs/cookbook.md` → "Add something to the screen", "Add a key binding"
- `game/ui/pause_menu.gd` (open/close with pause), `game/view2d/placeholder_tiles.gd`
  (terrain debug colours), `game/main.gd`, `game/input/player_controller.gd`

## Scope
Create `game/ui/map_view.gd`, `game/ui/town_map.gd`, `tests/game/test_map.gd`. Change
`game/ui/hud.gd` (minimap + hints), `game/main.gd` (M key, Esc, `--screen=map`),
`game/input/player_controller.gd` (no input while the map is open),
`game/input/input_actions.gd`, `game/launch_options.gd` (doc only).
**Out of scope:** clicking the map to walk there, other people on the map, objects on the
map, waypoints, more than one district (the code takes the first district's name only for
the title).

## Specification
- `MapView` (Control, `game/ui/map_view.gd`): draws the viewed level of the world as one
  texture pixel per cell, in the terrain `debug_color`s (nearest filtering), plus a player
  marker (`ViewConfig.PLAYER_MARKER_COLOR`, dark outline). Properties: `px_per_cell: float`,
  `follow: bool` (centre on the player, clamped to the map's edges), `show_labels: bool`
  (place names at their rect centres, outlined text). The texture is rebuilt when a game
  loads, the grid's `revision` changes or `Session.viewed_level` changes.
  - `static func map_image(grid: WorldGrid, content: ContentDB, level: int) -> Image`
  - `static func view_rect(map_cells: Vector2, center: Vector2, view_cells: Vector2) -> Rect2`:
    the visible cells, centred on `center`, kept inside the map; when the map is smaller than
    the view on an axis, it is centred on that axis.
  - `static func labels(content: ContentDB, level: int) -> Array[Dictionary]`:
    `{"name": String, "cell": Vector2}` (rect centre in cells) for each place on `level`.
- Minimap: a `MapView` (`follow`, 4 px per cell, 224×144) in a HUD panel at the top right,
  captioned "M map".
- `TownMap` (CanvasLayer, layer 14): dims the screen and shows a `MapView` (`show_labels`)
  of the whole level, scaled to the largest whole px per cell that fits 90% of the window,
  under the district's name, with "M or Esc to close". `is_open`, `open()` (remembers the
  speed and pauses), `close()` (restores it), like `PauseMenu`.
- Input action `"map": [KEY_M]`. main.gd: M toggles the map during a game, unless the Esc
  menu, the creator or the main menu is up. Esc closes an open map instead of opening the
  Esc menu. `PlayerController.town_map`: no movement, running or E while it is open.
  `--screen=map` opens it after the quick start (for screenshots).
- HUD hints: "M map" in both modes.

## Acceptance criteria
- [x] The map image is one pixel per cell in each terrain's debug colour → `test_map.gd`.
- [x] `view_rect` centres on the player, stops at every edge and centres a small map →
  `test_map.gd`.
- [x] Every place on the level gets a label at its centre; places on other levels don't →
  `test_map.gd`.
- [x] Opening the map pauses; closing restores the earlier speed (also when already paused)
  → `test_map.gd`.
- [x] The controller sends no movement while the map is open → `test_map.gd`.
- [x] Screenshots: `out/t0048_minimap.png` (minimap top right, player marker in it) and
  `out/t0048_map.png` (full map with names and the marker on Haus 12).
- [x] `tools/check.sh` passes.

## Implementation notes
- `MapView` (`game/ui/map_view.gd`) draws a one-pixel-per-cell texture of the viewed level
  (nearest filtering), rebuilt on a new sim, a grid revision or a level change. The minimap
  uses `follow`; the town map uses `show_labels`. Names near the edge are nudged inside
  instead of clipped, and the marker grows to half a cell on big maps.
- `TownMap` (`game/ui/town_map.gd`) copies `PauseMenu`'s open/close speed handling and
  picks the largest whole scale that fits (12 px per cell at 1280×720).
- main.gd: Esc or M closes an open map first; M opens it only when the Esc menu could open
  (game running, no menu screen or interaction menu); no other keys while it is open.
  `--screen=map` opens it after the quick start.
- Docs: the controls table (Shift and M, both M1 now), HUD notes, architecture module row,
  roadmap (M1 ✅ after the owner's playtest, M2 ▶).
- Verified: `tools/check.sh` 338 passed, 0 failed. Screenshots: `out/t0048_minimap.png`
  (minimap top right, marker on Haus 12), `out/t0048_minimap_west.png` (clamped at the
  west edge), `out/t0048_map.png` (full map, 16 names, marker in the flat, game PAUSED).
- Self-reviewed by the architect (the owner asked Opus to build tickets directly).

## Questions

## Review feedback
