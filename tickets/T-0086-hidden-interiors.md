---
id: T-0086
title: Hidden interiors (roofs from outside, dimmed street inside)
status: done
milestone: Art
size: L
owner: builder
depends_on: [T-0085]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
From outside you see buildings, not rooms: each building you're not in shows a roof, its
front (south) wall with windows and door, and its entrances. Walk through a door and that
building opens up while the street around it goes dark, so being inside feels like a
separate place. Nobody inside a closed building can be seen, and nothing inside can be
clicked. The owner chose this on 3 October over real separate maps ("option 1"). View
only: the sim, saves and people's lives don't change.

## Read first
T-0085, `game/view2d/depth_layer_2d.gd`, `person_view_2d.gd`, `object_view_2d.gd`,
`night_lights_2d.gd`, `day_night.gd` (`light_map`), `game/input/player_controller.gd`
(`person_at`, the click handler), `game/ui/bubbles_layer.gd`.

## Scope
- New: `game/view2d/interiors.gd` (`Interiors`), `game/view2d/roofs_view_2d.gd`
  (`RoofsView2D`, one `RoofView2D` per building), `game/view2d/roof_view_2d.gd`,
  `game/view2d/interior_dim_2d.gd` (`InteriorDim2D`), `tests/game/test_interiors.gd`.
- Change: `depth_layer_2d.gd` (the roofs join the y-sort), `main.gd` (the dim layer),
  `person_view_2d.gd`, `object_view_2d.gd`, `bubbles_layer.gd`, `player_controller.gd`
  (hidden people and objects can't be clicked), `day_night.gd` and `night_lights_2d.gd`
  (only the open building's rooms are lit), `placeholder_tiles.gd` (roof tiles),
  `art_set.gd` (optional `"roof"` entry like a terrain), `docs/art.md`, decision D34 in
  `docs/decisions.md` and `docs/architecture.md` (allowed by this ticket).
- **Out of scope:** separate maps, a setting to see through roofs, the town map.

## Specification
**`Interiors`** (RefCounted; `static var current: Interiors`, empty by default):
- `static func build(grid: WorldGrid) -> Interiors`: a building is a 4-connected group of
  indoor cells on one floor; walls and windows belong to every building with an indoor cell
  among their 8 neighbours.
- `func buildings_at(cell: Vector3i) -> PackedInt32Array`, `func cells(id: int) -> Array[Vector3i]`,
  `func bottom(id: int) -> int` (pixel y of the building's lowest edge).
- `func reveal_for(player_cell: Vector3i, viewed_level: int) -> PackedInt32Array`: the
  player's building when they are inside on the viewed floor; when they are inside on another
  floor, the buildings on the viewed floor that overlap it; else none.
- `var revealed: PackedInt32Array`; `func hidden(cell: Vector3i) -> bool`: the cell belongs to
  a building and none of its buildings is revealed.
- `func is_front(cell: Vector3i) -> bool`: a wall, window or door whose south neighbour is
  outside any building (drawn as the facade from outside); `func is_entrance(cell)`: a door
  next to an outdoor walkable cell.

**Drawing:** `RoofView2D` sits in the depth layer at its building's `bottom` (so a lamp or a
person south of it draws in front) and, while its building is hidden and on the viewed floor,
draws: the front cells as their face tiles, entrances as door tiles, every other cell as roof
(art set `"roof"` or placeholder shingles in one of three colours by building), with a dark
eave line along the roof's lower edge. `InteriorDim2D` (after the depth layer, `light_mask`
0) darkens every cell of the viewed floor outside the revealed buildings to 18 % while the
player is inside. `RoofsView2D` updates `Interiors.current.revealed` each frame from the
player and rebuilds on a new grid.

**Hiding:** people and objects on hidden cells are invisible and not clickable; their speech
bubbles don't show. The light map lights only revealed rooms (roofs stay dark at night; lamps
and windows still glow).

## Acceptance criteria
- [x] Buildings are found per floor, walls shared by two belong to both →
  `test_interiors.gd: test_buildings_and_shared_walls`
- [x] Reveal: inside → that building; outside → none; another floor → the overlapping ones →
  `test_reveal_for`
- [x] `hidden`, `is_front` and `is_entrance` → `test_hidden_front_and_entrances`
- [x] Hidden people can't be clicked → `test_command_mode.gd: test_hidden_people_cannot_be_clicked`
- [x] Only revealed rooms are lit → `test_day_night.gd: test_light_map_lights_only_open_rooms`
- [x] Screenshots: the Altmarkt from outside (roofs, fronts, doors; nobody visible inside),
  inside the flat (open, street dark), at noon and 22:00

## Implementation notes
- `game/view2d/interiors.gd` (`Interiors`): buildings by flood fill per floor, walls
  shared; `reveal_for`, `hidden`, `is_open`, `is_front`, `is_entrance`, and
  `shuts_out_street(command_mode)`.
- `roofs_view_2d.gd` / `roof_view_2d.gd`: one roof per building in the depth layer at the
  building's lowest edge; fronts and entrances drawn as their tiles, the rest as roof (art
  set `roof` or `PlaceholderTiles.build_roof_texture()`, three colours), a dark eave above
  the front. `RoofsView2D` updates `Interiors.current.revealed` when the player's cell or the
  viewed floor changes.
- `interior_dim_2d.gd`: darkens the floor outside the open building (and the outer halves
  of its thin walls, which otherwise left a pale frame of pavement), `light_mask` 0.
- **Changed from the spec (architect):** the street only goes dark in direct mode. In the
  first night screenshot free will had taken the player into the Kneipe and the whole town
  went black; command mode is for watching the town, so it keeps the street (other buildings
  stay closed). Bubbles from the street hide while you're indoors in direct mode.
- Hiding: `PersonView2D`, `ObjectView2D`, `BubblesLayer`, and `PlayerController` (people via
  `person_at`, objects in the click handler). `DayNight.light_map(..., interiors)` lights only
  open rooms; `NightLights2D` rebuilds when the open building changes.
- D34 in `docs/decisions.md`; `docs/architecture.md`, `docs/art.md`,
  `data/art2d/README.md` (`roof`).

Verified: `tools/check.sh` → 719 passed (new `test_interiors.gd` ×5,
`test_hidden_people_cannot_be_clicked`, `test_light_map_lights_only_open_rooms`,
`test_roof_tile`). Screenshots: `out/t0086-noon-out.png` (from the square: roofs, Haus 12's
front and door, nobody inside visible), `out/t0086-inside.png` (the flat open, the street
dark), `out/art/placeholder/night.png` (command mode at 22:00: street lit by lamps, Haus 12 a
dark roof, the Kneipe open with the player inside).

## Questions

## Review feedback
