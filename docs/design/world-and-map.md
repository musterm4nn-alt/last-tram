# World and map

## The grid

- The town is a grid of cells, **1 cell ≈ 1 m**. Coordinates are `Vector3i(x, y, level)`:
  x grows east, y grows south, and level is the floor (0 = street, 1 = first floor,
  −1 = basement or metro).
- Each cell has a **terrain** (data: `data/terrain.json`): floor, wall, door, window, road,
  sidewalk, rail, grass, water... Terrain decides `walkable`, `blocks_sight`, `indoor`,
  `surface` and `path_cost` (see Navigation).
- **Walls occupy whole cells** ([decisions D3](../decisions.md)). Doors are walkable but block
  sight; windows block movement but not sight.
- Outside the grid is void (not walkable).

## Objects (M1)

- Furniture, appliances, trees, benches, counters, ATMs, bins... are **world objects**:
  `{id, def_id, cell (origin), rotation 0–3}`.
- An object definition (`data/objects/*.json`) gives its footprint size, whether it blocks
  movement and sight, its **use slots** (cells next to or on it where a person stands or sits
  to use it, with a facing), tags (`bed`, `seat`, `fridge`, `counter`...), price, and debug
  colour.
- The object layer sits on top of terrain: a cell is walkable if its terrain is walkable and
  no blocking object covers it.
- Authoring: each district has an `objects.json` listing placements; later build mode places
  them at runtime.

## Places, lots and rooms

- **Places** (M0, content only) are named rectangles in `district.json`: the Späti, Haus 12,
  Altmarkt... The HUD shows where you are.
- **Lots** (M2) turn places into world state: owner (person, household, business or city),
  kind, **access rules** (public / private / business hours / staff only), address, and for
  homes rent and tenant. Built in T-0032: `World.lots` (one per place, access and hours
  from `district.json`), `Person.home_lot_id`, and `Lots.may_enter`, which free will
  respects. Being on a private lot without permission is **trespassing** (M4).
  One building can hold many lots: each flat is a lot on its level.
- **Rooms** (M2) are computed, not authored: a flood fill bounded by walls and doors. They are
  used for privacy (bathrooms, bedrooms), roof cut-away, "indoors", and what witnesses
  can see.

## Districts

- A district is a hand-made chunk of town in `data/world/districts/<id>/`: ASCII level maps
  (`level_0.txt`, `level_1.txt`...), `district.json` (origin, places, spawn), and later
  `objects.json`.
- The world is the union of all districts listed in `data/world/world.json`, each at its
  origin. Towns grow by adding districts that connect by street and tram.
- **District 1: Altstadt** (72 × 44): canal and promenade in the north; St. Nikolai, Café
  Wolke, Waschsalon Blitz, Kneipe Zum Anker, Haus 3; **Hauptstraße** with two tram tracks and
  zebra crossings; the **Altmarkt** square with fountain and trees; Späti Kaya and Imbiss
  Anadolu with a Hinterhof behind; **Haus 12** (the player's ground-floor flat: living room,
  kitchen, bedroom, bathroom); the Polizeiposten; Kirchgasse; the Stadtpark.
- Authoring now: agents edit the ASCII maps. From M5: the in-game **town editor** (build
  mode without limits, saving back to the district files) lets the owner hand-craft the town.

## Multiple floors (M2)

- Each floor is a separate ASCII level file. **Stairs** cells connect a cell on level L with
  the same x, y on level L+1.
- The view shows one level at a time: the player's level. Levels above are hidden while
  you're inside. Command mode can page through levels.
- Altbau buildings get upper-floor flats (NPC homes); the metro (later) runs on level −1.

## Navigation (M1+)

- One `AStarGrid2D` per level, built from walkability (a derived cache, never saved), plus
  stair links between levels (T-0030): a stairs cell links to the stairs cell straight above
  it, and routes between levels are a Dijkstra over stairs cells (hop cost 2). Built in T-0003: `sim.nav` (`Pathfinder`) with
  `find_path(from, to)` (the cells to walk through, excluding the start) and
  `is_reachable(from, to)`. Diagonal steps are allowed but never cut a blocked corner, and
  each level's graph is rebuilt lazily when `WorldGrid.revision` changes.
- Pedestrian costs by surface (terrain `path_cost`): sidewalk / floor / crossing 1,
  grass 1.5, road and rail 4. People prefer pavements and zebra crossings but can jaywalk.
- Private lots are excluded from a person's paths unless they're allowed in (from M2).
  Burglars ignore that (M4).

## Line of sight (M4, for witnesses)

A grid raycast on one level, blocked by `blocks_sight` terrain and sight-blocking objects, up
to a sight range that shrinks at night.

## Spatial queries (M2)

A spatial hash (16 × 16-cell chunks, derived) answers "who is near this cell" and "which
objects with tag X are near" quickly.
