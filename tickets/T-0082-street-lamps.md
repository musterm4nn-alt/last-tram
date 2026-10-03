---
id: T-0082
title: Street lamps in the Altstadt
status: todo
milestone: Art
size: S
owner: builder
depends_on: []
builder:
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
- Def: `{ "id": "street_lamp", "name": "Street lamp", "size": [1, 1], "blocks_movement": true,
  "blocks_sight": false, "tags": ["street_lamp"], "use_slots": [{ "offset": [0, 1],
  "facing": [0, -1] }], "price": 0, "debug_color": "#3d4148" }` (a use slot is required by
  the loader; nothing uses it yet).
- Placements on level 0: along the Hauptstraße's south pavement (y 22) every 8 cells, on the
  north pavement (y 16) every 8 cells offset by 4, around the Altmarkt's edge (about 6), and
  one by the Haus 12 door. Only on `sidewalk` or `cobblestone` cells, never on a door's
  neighbour, never in a use slot of another object, never where they'd cut off a path.
- Document the placements in the objects file's `_doc`.

## Acceptance criteria
- [ ] Every lamp stands on sidewalk or cobblestone, next to no door, and on no other object's
  footprint or use slot → `test_street_lamps.gd: test_lamps_stand_on_pavement`
- [ ] Every lot's entrance is still reachable from the player's door →
  `test_lamps_block_no_route` (A* from the Haus 12 door to each lot's door)
- [ ] At least 20 lamps on level 0 → `test_enough_lamps`
- [ ] `tools/check.sh` passes, and `tools/simrun.sh --days=7 --check-m2` passes on seeds 1–3
  (paste the lines in the notes)

## Implementation notes

## Questions

## Review feedback
