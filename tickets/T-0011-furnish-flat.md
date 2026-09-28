---
id: T-0011
title: Furnish the player's flat (a bathroom, objects and home interactions)
status: done
milestone: M1
size: S
owner: builder
depends_on: [T-0006]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The flat in Haus 12 has everything for a day at home: a small bathroom (shower and sink), a
stove next to the fridge, a kitchen table, and a desk with a laptop, plus the existing bed,
sofa and TV, each with its interactions: cook a meal, take a shower, wash your hands, nap,
browse the web and video call a friend (the only way to fill Social until the phone in M3).
No toilet: there is no bladder need (D21). This is data plus tests; no code changes.

## Read first
- `docs/cookbook.md` → "Edit the town map or add a place"
- `data/objects/furniture.json`, `data/interactions/basics.json` (T-0006), 
  `data/world/districts/altstadt/objects.json`, `data/world/districts/altstadt/level_0.txt`
- `tests/sim/test_objects.gd` (`test_new_game_has_all_altstadt_objects`)

## Scope
Change `data/world/districts/altstadt/level_0.txt` (six characters), `data/objects/furniture.json`,
`data/world/districts/altstadt/objects.json`, `data/interactions/basics.json` (one rate);
create `data/interactions/home.json` and `tests/sim/test_home_content.gd`; update
`tests/sim/test_objects.gd` (the object count). Update the `_doc` of `objects.json`.
**Out of scope:** any code in `sim/` or `game/`; privacy for the shower (rooms arrive in M2);
tuning needs for free will (T-0016 tunes if needed); items and money.

## Specification

### Map: a 2×2 bathroom in the entrance room (`level_0.txt`, district-local = world here)
Replace exactly these characters (x = column, y = line, both from 0); every row keeps its
length:
- (48,26) `.`→`#`, (49,26) `.`→`#`  (the bathroom's north wall)
- (48,27) `.`→`_`, (49,27) `.`→`_`, (50,27) `.`→`D`  (bathroom floor, door to the hall)
- (48,28) `.`→`_`, (49,28) `.`→`_`, (50,28) `.`→`#`  (bathroom floor, east wall)
The flat (x 47–60, y 23–34) then reads:
```
###D#W####W###
#......#_____#
#......#_____#
W##....D_____W
#__D...#_____#
#__#...#_____#
####D#####D###
#......#_____#
W......#_____W
#......#_____#
#......#_____#
####W#####W###
```
The spawn (50,26) stays walkable.

### Objects (`furniture.json`: add these; all `"blocks_movement": true, "blocks_sight": false`)
| id | name | size | tags | use_slots (offset → facing) | price | debug_color |
|---|---|---|---|---|---|---|
| `stove` | Stove | [1,1] | `stove` | [0,1] → [0,-1] | 40000 | `#636e72` |
| `shower` | Shower | [1,1] | `shower` | [1,0] → [-1,0] | 60000 | `#81ecec` |
| `sink` | Sink | [1,1] | `sink` | [1,0] → [-1,0] | 15000 | `#c7ecee` |
| `kitchen_table` | Kitchen table | [2,1] | `seat`, `table` | [0,1] → [0,-1]; [1,1] → [0,-1] | 20000 | `#a0785a` |
| `desk` | Desk with laptop | [1,1] | `computer` | [0,1] → [0,-1] | 90000 | `#4a4e69` |

And give `sofa` the tags `["seat", "couch"]`.

### Placements (`altstadt/objects.json`, rotation 0; keep the four existing ones)
`stove` (58,24,0) · `shower` (48,27,0) · `sink` (48,28,0) · `kitchen_table` (56,27,0) ·
`desk` (48,30,0).

### Interactions
In `basics.json`, sleep's `need_rates` becomes `{"energy": 16.0, "comfort": 10.0}` (lying in
bed is comfortable; comfort otherwise drains all night). New file `data/interactions/home.json`,
all fixed-length (`duration_minutes`), `finish_needs` `{}` unless given:
| id | name | object_tags | minutes | need_rates | finish_needs | advertise |
|---|---|---|---|---|---|---|
| `cook_meal` | Cook a meal | `stove` | 30 | {} | hunger 60 | hunger 60 |
| `take_shower` | Take a shower | `shower` | 15 | {} | hygiene 70 | hygiene 70 |
| `wash_hands` | Wash your hands | `sink` | 2 | {} | hygiene 10 | hygiene 10 |
| `nap` | Nap | `couch`, `bed` | 45 | energy 12, comfort 20 | {} | energy 10, comfort 15 |
| `browse_web` | Browse the web | `computer` | 30 | fun 20 | {} | fun 10 |
| `video_call` | Video call a friend | `computer` | 45 | social 60 | {} | social 45 |

## Acceptance criteria (`tests/sim/test_home_content.gd` unless named)
- [ ] `ContentDB.load_default()` has no errors.
- [ ] Every object placed in a new game has at least one use slot reachable from the
  player's spawn (`sim.nav.find_path(spawn, slot_cell)` is not empty, or the slot is the
  spawn), for every object, not just the new ones.
- [ ] Every interaction in `content().interactions` is offered by at least one object placed
  in the new game (`Interactions.offered_by`), so nothing in the data is unusable in the flat.
- [ ] The map: (48,27) is tiled floor, (50,27) is a door, (48,26) and (50,28) are walls, and
  the spawn is walkable.
- [ ] Each new interaction does what the table says, checked with one test that stands the
  player on a slot and runs it (e.g. `cook_meal` from hunger 20: 30 minutes, then hunger
  20 − 3 + 60; `video_call` 45 minutes: social + 45 − 3). Build the sim with
  `SimFactory.new_game(content(), 1)` and set `player.pos` to the slot cell centre.
- [ ] `test_objects.gd`: `test_new_game_has_all_altstadt_objects` no longer hard-codes 4: it
  checks that every placement in `altstadt/objects.json` (parsed directly) was loaded.
- [ ] Screenshot: `tools/screenshot.sh out/t0011.png --debug --zoom=1` shows the whole flat
  with nine labelled objects and their slot dots, and the new bathroom walls. Open it and
  look at it.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request ("write the code
yourself"). A DeepSeek session started earlier could not be stopped in time and pushed its own
T-0011 branch; per the owner's instruction it was not used (its commit is kept locally only,
as `refs/archive/t0011-deepseek`, fddd1b2).
- Data exactly as specified: the six map characters (a 2×2 tiled bathroom with a door to the
  hall), five objects (stove, shower, sink, kitchen table, desk with laptop), the sofa's
  `couch` tag, five placements, sleep's comfort rate, and `data/interactions/home.json` with
  cook_meal, take_shower, wash_hands, nap, browse_web and video_call. The layout was checked
  before the ticket was written (no content errors; every object reachable).
- `tests/sim/test_home_content.gd` (9 tests): content valid; the bathroom on the map; every
  object has a slot reachable from the spawn; every interaction is offered in the flat; and
  each new interaction's exact effect (cook 20 → 77 after 30 min, shower, hand washing, nap,
  browsing, video call, and sleep's comfort).
- `test_objects.gd`: the object-count guard compares with the placements in the JSON file
  instead of a hard-coded number (a tautology like `size() == size()` would prove nothing).
- Checks: `tools/check.sh` 183 passed, 0 failed. Three data mutations (cooking gives 50,
  no bathroom door, no desk) each fail at least one test. Screenshots `out/t0011.png`
  (F3, slot dots) and `out/t0011_nodebug.png` show all nine labelled objects, the bathroom
  and its door.

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
