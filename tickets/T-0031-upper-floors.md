---
id: T-0031
title: Upper floors - flats above the shops for about 30 residents
status: todo
milestone: M2
size: M
owner: builder
depends_on: [T-0030, T-0032, T-0049]
builder:
review_rounds: 0
---

## Goal
Four Altstadt buildings get first and second floors with stairwells: 14 new flats, plus Haus
3's ground floor, so about 30 neighbours (T-0034) can live in town. Every flat is a private
lot with a bed, fridge, stove, sink, shower and sofa, reachable from the street by stairs.

## Read first
- `docs/design/world-and-map.md` → "Multiple floors (M2)", "Districts"
- `docs/cookbook.md` → "Add a terrain type", "Edit the town map or add a place"
- As merged: `data/world/districts/altstadt/` (`level_0.txt`, `district.json`,
  `objects.json`), `sim/content/world_loader.gd` (levels, places, objects),
  `sim/world/world.gd` (`from_dict`, lots), `sim/world/lots.gd`

## Scope
Create `data/world/districts/altstadt/level_1.txt`, `level_2.txt`,
`tests/sim/test_upper_floors.gd`. Change `level_0.txt` (stairwells only), `district.json`
(levels, places), `objects.json` (flat furniture), `data/terrain.json` (open air),
`sim/world/world.gd` (lots for new places), `docs/design/world-and-map.md` (the district
description). **Out of scope:** residents (T-0034), new object kinds, roof cut-away,
furniture for Haus 12 (the player's flat stays exactly as it is).

## Specification
- Terrain `open_air`: glyph `-`, name "Open air", not walkable, not sight-blocking, outdoor,
  surface `none`, `path_cost` 1.0, debug colour `#0e0f12` (like void). Upper levels use it
  outside buildings, because trailing spaces don't survive editors.
- Levels 1 and 2 are 72 × 44 like level 0. Each building keeps its ground-floor outline
  (walls `#`, windows `W` in the same places), with a 1-cell stairs column (`^`) at the
  same x, y on levels 0, 1 and 2.

| Building (new name) | Ground-floor footprint | Stairwell on level 0 | Flats on levels 1 and 2 |
|---|---|---|---|
| Haus 5 (Café Wolke + Waschsalon Blitz) | x 20–41, y 6–15 | carved from the café's SE corner, new street door in the south wall | 2 per floor (left, right) |
| Haus 9 (Kneipe Zum Anker) | x 45–56, y 6–15 | carved from the Kneipe's SE corner, new street door | 1 per floor |
| Haus 3 | x 57–70, y 6–15 | a hall inside the existing street door (63, 15); the ground floor becomes one flat with its own door off the hall | 2 per floor |
| Haus 14 (Späti Kaya + Imbiss Anadolu) | x 1–17, y 23–30 | carved from the Imbiss's SW corner, new door to the Hinterhof in the back wall | 2 per floor |

  Shops keep their doors and at least 80% of their floor. Stair halls are tiled or stone
  floor, walled off from the shop.
- Places (in `district.json`, before the shop and building places they overlap):
  - Stairwells: `haus_<n>_stairs_<level>`, name "Haus <n>, stairwell", kind `hallway`
    (public by default), one per level.
  - Flats: `haus_<n>_<level>_<side>` (side `left`/`right`, or `flat` for Haus 9), name
    "Haus <n>, <1st|2nd> floor <left|right>" (Haus 9: "Haus 9, 1st floor"), kind `home`.
    Haus 3's ground floor keeps id `haus_3` (name "Haus 3, ground floor").
  - `levels` gains `"1": "level_1.txt", "2": "level_2.txt"`.
- Furniture per new flat (objects.json, rotation as needed, every slot usable):
  `bed_double`, `fridge`, `stove`, `sink`, `shower`, `sofa`. Haus 3's ground floor too.
- `World.from_dict`: after reading saved lots, add a lot (new id) for each place that has
  none, so saves from before T-0031 get the new flats' lots. Saves keep their own saved
  grid: an old game keeps the old town (no upper floors); a new game is needed to see them.

## Acceptance criteria (`tests/sim/test_upper_floors.gd`)
- [ ] The content loads without errors; Altstadt has levels 0, 1 and 2, and 15 home places
  besides the player's (14 upstairs + Haus 3 ground floor).
- [ ] From the Altmarkt (30, 30, 0), every home place has a reachable walkable cell
  (`sim.nav.is_reachable`), and every stairwell connects its levels.
- [ ] Every new flat has the six required objects inside its rect, each with a free use slot
  reachable from the Altmarkt.
- [ ] The player's flat, spawn and objects are unchanged (`test_home_content.gd` passes
  untouched), and the shops keep their door cells.
- [ ] A save with lots from before (built from the v3 fixture after loading, then with the
  new places' lots removed) gets lots for every place on load.
- [ ] `tools/check.sh` passes. Screenshots with `--level=1` and `--level=2` (`--zoom=0`):
  `out/t0031_l1.png`, `out/t0031_l2.png`, and `out/t0031_l0.png` showing the stairwells.

## Implementation notes

## Questions

## Review feedback
