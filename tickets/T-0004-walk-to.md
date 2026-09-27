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
- `sim/world/pathfinder.gd` (T-0003, merged): `sim.nav.find_path(from, to) -> Array[Vector3i]`
  returns the cells to walk through **after** `from`, ending with `to`. It is empty if `to` is
  unreachable, if `from` or `to` is not walkable, if from == to, or if they are on different
  levels. Consecutive cells are neighbours (diagonals included), and a diagonal step never
  cuts a blocked corner.

## Scope
Create `sim/commands/walk_to_command.gd`, `tests/sim/test_walk_to.gd`.
Change `sim/people/person.gd`, `sim/systems/movement_system.gd`,
`sim/commands/set_move_intent_command.gd`, `sim/core/command_registry.gd`.
**Out of scope:** UI for clicking (T-0009), actions (T-0006/T-0007).

## Specification
- `Person.path: Array[Vector3i]`: the remaining cells to walk through (saved). Save as a list
  of `Ser.cell()` and read with a default of `[]` so old saves still load.
- `MovementSystem.step()` per person (after `person.prev_pos = person.pos`, as today):
  1. If `move_intent != Vector2.ZERO`: direct movement exactly as today (the path is ignored).
  2. Else if `path` is not empty: follow it with a new
     `static func follow_path(sim: Sim, person: Person, budget: float) -> void`, where
     `budget = person.walk_speed * cells_per_step` is the distance this step may cover (in
     cells). Implement it exactly like this:
     ```gdscript
     while budget > 0.0 and not person.path.is_empty():
         var next: Vector3i = person.path[0]
         if not sim.world.grid.is_walkable(next):
             # Something now blocks the route (e.g. an object was placed).
             person.path.clear()
             sim.emit_event(&"path_blocked", {"person_id": person.id})
             return
         var centre := Vector2(next.x + 0.5, next.y + 0.5)
         var to_centre := centre - person.pos
         var dist := to_centre.length()
         if dist > 0.0:
             person.facing = _cardinal(to_centre)
         if dist <= budget:
             # A cell centre on a walkable cell is always a legal spot.
             person.pos = centre
             person.path.remove_at(0)
             budget -= dist
         else:
             move_person(sim.world.grid, person, to_centre / dist * budget)
             budget = 0.0
     ```
     Leftover distance carries on to the next waypoint in the same step, so the travel time
     is `ceil(path length / step length)` steps.
  3. Only the next waypoint (`path[0]`) is checked for being blocked. A blocked cell further
     along is found when it becomes the next waypoint, so the person stops in the cell before
     it.
- `SetMoveIntentCommand.apply()`: a non-zero direction also **clears the path** (the player
  takes over). A zero direction leaves the path alone.
- `WalkToCommand(person_id: int, target: Vector3i)`, type id `"walk_to"` (copy the example in
  the cookbook). `apply()`: unknown person → ignore. Then:
  - `target == person.cell()`: clear `person.path` and `move_intent` (already there: stop).
    No event.
  - Else `var path := sim.nav.find_path(person.cell(), target)`. If it is empty: emit
    `&"path_failed"` `{"person_id": person_id, "target": Ser.cell(target)}` and change
    nothing (an earlier path keeps going).
  - Else: `person.path = path` and `person.move_intent = Vector2.ZERO`.
- Register in `CommandRegistry`.

## Acceptance criteria (`tests/sim/test_walk_to.gd`, worlds from `SimFactory.from_rows`)
- [ ] WalkTo in an open room arrives at the target cell centre, and the path ends empty.
- [ ] WalkTo around a wall arrives, and the person never overlaps a blocked cell on the way
  (check `MovementSystem.is_box_blocked` every step).
- [ ] Travel time on a straight path of N cells, starting at a cell centre, is exactly
  `ceil(N / (walk_speed / SimClock.STEPS_PER_GAME_MINUTE))` steps (so leftover movement
  really carries over between waypoints). Use N = 5: at the default 4.5 cells per game
  minute that is 23 steps (stopping at every waypoint would take 25). Avoid an N that
  divides evenly, where float rounding could go either way.
- [ ] Unreachable target → `path_failed` event with the target, no movement, and an earlier
  path is kept. Target == the person's own cell → path cleared, no event.
- [ ] A non-zero `SetMoveIntentCommand` mid-path clears the path; the person then moves only
  by intent. A zero one leaves the path alone.
- [ ] Placing an object on a later cell of the path → the person walks up to it, then
  `path_blocked` fires once, the path is cleared, the person stands still, and they never
  overlap the object's cells.
- [ ] `facing` points along the walk (e.g. east while walking east).
- [ ] Save in the middle of a walk, load, continue = the same result as an uninterrupted run
  (extend the pattern from `test_save.gd`, comparing `SaveCodec.to_json`). A save without a
  `path` key still loads (the path is empty).
- [ ] `tools/check.sh` passes (`test_commands.gd` covers registration and round trip).

## Implementation notes

## Questions

## Review feedback
