# Build and buy mode (M5)

## Modes

- **Buy mode:** buy, place, move, rotate and sell objects (furniture, appliances,
  decoration).
- **Build mode:** walls, doors, windows, flooring, wallpaper and paint, stairs, extra storeys.
- Entered from command mode (key `B`). Time is **paused** by default (a setting allows live
  building).

## Everything is a Command

`PlaceObjectCommand`, `MoveObjectCommand`, `RotateObjectCommand`, `SellObjectCommand`,
`PaintFloorCommand(rect)`, `BuildWallCommand(line)`, `PlaceDoorCommand`,
`PlaceWindowCommand`, `AddStairsCommand`, `AddLevelCommand`.

The sim validates every one:
- **permission** (see below) and **funds**;
- the footprint is free and on suitable terrain;
- use slots stay reachable, doors aren't blocked, and nobody is walled in (a reachability
  check with the pathfinder);
- structural sense (a door must sit in a wall; stairs need space on both levels).

The view shows a placement ghost (green or red, with the reason), and uses the same
validation function for the preview.

## Permissions

| Who | Can |
|---|---|
| Owner | everything on their lot |
| Tenant | objects and decoration; paint and wallpaper; no walls, doors or stairs |
| Visitor / public | nothing |
| Town editor (dev) | everything everywhere, including terrain |

## Money

Objects have a price. Selling refunds 60%, or 100% within the same build session (undo).
Walls, flooring and paint cost per cell. Undo/redo work within the session.

## Environment score

Each room gets a comfort and beauty score from its objects and cleanliness, which becomes a
home moodlet ("Cosy flat +8" / "Dump −10").

## Town editor (dev mode)

Build mode without limits, plus terrain painting, place and lot editing, and **saving back to
the district files** (ASCII levels, `objects.json`, `district.json`). File writing happens in
`game/` (an exporter), never in `sim/`. This is how the owner hand-crafts the town without an
agent.
