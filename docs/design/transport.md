# Getting around

## Movement modes

| Mode | When |
|---|---|
| Walk | always (M0) |
| Run | direct mode, hold Shift: faster, drains energy, looks suspicious near police (M4) |
| Ride transit | M7: inside a tram or bus, position follows the vehicle |
| Bike / e-scooter | later: sidewalks and roads |
| Car | later: roads only; driving skill |

## Surfaces

Terrain has a `surface` (`sidewalk`, `road`, `rail`, `floor`, `grass`...). Pathfinding costs
come from surfaces ([world-and-map.md](world-and-map.md#navigation-m1)); later, vehicles are
restricted by them (cars on `road`, trams on `rail`).

## Public transport (M7)

- **Lines:** an ordered list of stops plus the path between them (cells), in
  `data/transit/*.json`.
- **Vehicles:** entities moving along their line at a set speed, dwelling at stops. The tram on
  Hauptstraße uses the two tracks, one per direction.
- **Timetable:** headway by time of day (every 10 minutes by day, 20 in the evening). **The
  last tram** leaves around 00:40, then the night bus runs hourly.
- **Riding:** wait at the stop, board (the "board" interaction), ride (time passes; a fast-forward
  option for the player), alight.
- **Fares:** ticket machine or phone app. Riding without a ticket is **fare dodging**
  (severity 1); inspectors do random checks and fine you.
- **Background tier:** a trip is a travel-time estimate from the timetable (wait + ride +
  walk).

## Trip planning

People choose between walking and transit by estimated door-to-door time (and money for
car or taxi later). Plans are computed on a coarse graph of stops, lot entrances and street
nodes, and executed with the fine grid pathfinder near the person.

## Vehicles later (bikes, scooters, cars)

A generic **Vehicle** entity: `{id, kind, pos, heading, speed, level, occupants (ids),
controller (player / npc / route), owner}`. Cars add lanes and directions on roads (data),
parking spots, traffic lights, collisions, and **car theft** (crime); bikes add locks and bike
theft. The M7 transit vehicles use this same entity, so bikes and cars plug in without
redesign.
