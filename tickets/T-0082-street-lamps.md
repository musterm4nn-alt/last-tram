---
id: T-0082
title: Street lamps in the Altstadt
status: done
milestone: Art
size: S
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The streets and the Altmarkt have lamp posts, so the night view (T-0083) has something to
light the town with. They are ordinary world objects with no interactions yet.

## Read first
`data/objects/public.json`, `data/world/districts/altstadt/objects.json` (its `_doc`),
`level_0.txt`, `sim/content/object_loader.gd`.

## Scope
- Change: `data/objects/public.json` (the `street_lamp` def),
  `data/world/districts/altstadt/objects.json` (placements, **appended at the end** so
  existing object ids don't move), a test in `tests/sim/` (`test_street_lamps.gd`).
- **Out of scope:** light (T-0083), any interaction with a lamp, other districts.

## Specification
- Def: `{ "id": "street_lamp", "name": "Street lamp", "size": [1, 1], "blocks_movement": false,
  "blocks_sight": false, "tags": ["street_lamp"], "use_slots": [{ "offset": [0, 1],
  "facing": [0, -1] }], "price": 0, "debug_color": "#3d4148" }` (a use slot is required by
  the loader; nothing uses it yet). A lamp post is thin and stands at the kerb, so it
  doesn't block walking: the pavements are one cell wide, and a blocking post would push
  people onto the road and change every route (architect's change while building).
- Placements on level 0: along the Hauptstraße's south pavement (y 22) every 8 cells, on the
  north pavement (y 16) every 8 cells offset by 4, around the Altmarkt's edge (about 6), and
  one by the Haus 12 door. Only on `sidewalk` or `cobblestone` cells, never on a door's
  neighbour, never in a use slot of another object.
- Document the placements in the objects file's `_doc`.

## Acceptance criteria
- [x] Every lamp stands on sidewalk or cobblestone, next to no door, and on no other object's
  footprint or use slot → `test_street_lamps.gd: test_lamps_stand_on_pavement`
- [x] Lamps block no route: every lamp cell is still walkable for the pathfinder →
  `test_lamps_block_no_route`
- [x] At least 20 lamps on level 0 → `test_enough_lamps`
- [x] `tools/check.sh` passes, and `tools/simrun.sh --days=7 --check-m2` passes on seeds 1–3
  (paste the lines in the notes)

## Implementation notes
- `street_lamp` in `data/objects/public.json`, **not blocking** (see the spec: the pavements
  are one cell wide, so a blocking post would push people onto the road).
- 32 lamps appended to the Altstadt's `objects.json` (earlier object ids unchanged), picked
  by a throwaway script with the rules above: y 16 and y 35 every 8 cells from x 4, y 22
  every 8 from x 0 (the one at x 32 dropped: tram shelter), six around the Altmarkt. Lamps on
  the south pavement are turned (rotation 2) so their use slot is on the walkable road.
- `tests/sim/test_street_lamps.gd`: pavement, no door next to it, no other object's slot or
  cell; walkable; at least 20 on level 0.

Verified: `tools/check.sh` → 698 passed. `sim_runner --days=7 --check-m2` seeds 1, 2, 3:
`M2 CHECK: PASSED` ×3. `out/t0082.png` (zoom 2, command mode) shows the posts along both
pavements and at the square's corners (placeholder "Lam" blocks).

## Questions

## Review feedback
