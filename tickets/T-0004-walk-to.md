---
id: T-0004
title: Follow paths and WalkToCommand
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0003]
builder:
review_rounds: 0
---

## Goal
People can walk along a computed path. `WalkToCommand` sends someone to a cell (used later by
click-to-walk and by actions). Direct WASD input always overrides a path.

## Read first
- `sim/systems/movement_system.gd` (you extend it), `sim/people/person.gd`
- `docs/cookbook.md` → "Add a Command", "Add a field to Person"
- T-0003's `Pathfinder` (`sim.nav`)

## Scope
Create `sim/commands/walk_to_command.gd`, `tests/sim/test_walk_to.gd`.
Change `sim/people/person.gd`, `sim/systems/movement_system.gd`,
`sim/commands/set_move_intent_command.gd`, `sim/core/command_registry.gd`.
**Out of scope:** UI for clicking (T-0009), actions (T-0006/T-0007).

## Specification
- `Person.path: Array[Vector3i]`: the remaining cells to walk through (saved). Save as a list
  of `Ser.cell()` and read with a default of `[]` so old saves still load.
- `MovementSystem.step()` per person:
  1. If `move_intent != ZERO`: direct movement exactly as today (the path is ignored).
  2. Else if `path` is not empty: move towards the **centre** of `path[0]` (cell + 0.5, 0.5) at
     `walk_speed`, using `move_person()` for collision. If the remaining distance is ≤ the
     step length, snap to the centre and pop `path[0]` (carry over leftover movement to the
     next waypoint only if it's simple; otherwise it's fine to stop this step). Update
     `facing` like direct movement does.
  3. If a waypoint becomes unreachable (not walkable, e.g. an object was placed), clear
     the path and emit `&"path_blocked"` `{"person_id"}`.
- `SetMoveIntentCommand.apply()`: a non-zero direction also **clears the path** (the player
  takes over).
- `WalkToCommand(person_id: int, target: Vector3i)`, type id `"walk_to"`: computes
  `sim.nav.find_path(person.cell(), target)`. If empty (and target != current cell), emit
  `&"path_failed"` `{"person_id", "target": Ser.cell(target)}` and leave the path unchanged.
  Otherwise set `person.path` and clear `move_intent`.
- Register in `CommandRegistry`.

## Acceptance criteria (`tests/sim/test_walk_to.gd`)
- [ ] WalkTo in an open room arrives at the target cell centre, and the path ends empty.
- [ ] WalkTo around a wall arrives, and the person never overlaps a blocked cell on the way
  (check `MovementSystem.is_box_blocked` every step).
- [ ] Travel time matches the path length and walk speed (within one step) on a straight
  path.
- [ ] Unreachable target → `path_failed` event, no movement.
- [ ] A non-zero `SetMoveIntentCommand` mid-path clears the path; the person then moves only
  by intent.
- [ ] Placing an object on the remaining path → `path_blocked` event, the path is cleared,
  and the person stops.
- [ ] Save in the middle of a walk, load, continue = the same result as an uninterrupted run
  (extend the pattern from `test_save.gd`).
- [ ] `tools/check.sh` passes (`test_commands.gd` covers registration and round trip).

## Implementation notes

## Questions

## Review feedback
