---
id: T-0007
title: Walk to a free use slot before performing; direct input cancels
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0004, T-0006]
builder:
review_rounds: 0
---

## Goal
Queued interactions now walk the person to the object first. They choose a free use slot,
walk there with pathfinding, then perform. Two people never use the same slot. If the
player presses WASD, the current action is cancelled (the player takes over).

## Read first
- `docs/design/actions-and-autonomy.md` → "Actions (runtime)" step 1, "Control modes"
- As merged: `sim/systems/action_system.gd` and `sim/actions/interactions.gd` (T-0006),
  `sim/systems/movement_system.gd` (T-0004: a person with a non-empty `path` and a zero
  `move_intent` walks it; a blocked next cell clears the path and emits `path_blocked`),
  `sim/world/pathfinder.gd` (T-0003).
- Useful as merged: `Interactions.slot_at_person(sim, person, object_id) -> int`,
  `WorldObject.slot_count(content)`, `slot_cell(content, i)`, `slot_facing(content, i)`,
  `world.get_object(id)`, `grid.is_walkable(cell)`, `sim.nav.find_path(from, to)`.
  `Sim.default_systems()` runs ActionSystem **before** MovementSystem (D23), so a route set in
  `step()` is walked in the same step.

## Scope
Change `sim/systems/action_system.gd`, `sim/actions/interactions.gd`,
`tests/sim/test_actions.gd` (only the not-at-slot test, see below). Create
`tests/sim/test_action_routing.gd`. If `action_system.gd` would pass 350 lines, move the
routing helpers into a new `sim/actions/slot_router.gd` (`SlotRouter`, static functions).
**Out of scope:** UI (T-0010), autonomy (T-0012), reserving slots for queued (not yet
routing) actions.

## Specification
- Slots are **reserved implicitly**: a slot counts as taken if any *other* person's front
  action targets the same object with the same `slot_index` and is `ROUTING` or
  `PERFORMING`. Add to `Interactions`:
  ```gdscript
  ## True if another person's front action is routing to or performing on this slot.
  static func slot_taken(sim: Sim, object_id: int, slot_index: int, except_person_id: int) -> bool
  ```
  It scans `sim.world.people`; there is no extra saved state.
- Choosing a route (used by `QUEUED` step 2 and `ROUTING` step 3), for the front action:
  1. `free` = slot indices of the target that are not `slot_taken(...)`. If `free` is empty
     → fail with reason `"no_free_slot"`.
  2. For each free slot (index order) whose cell `grid.is_walkable`, compute
     `sim.nav.find_path(person.cell(), slot_cell)`; ignore empty results. Pick the smallest
     `path.size()` (ties: lowest slot index). None → fail with reason `"no_path"`.
  3. Set `action.slot_index`, `person.path` to that path, `action.state = Action.ROUTING`,
     and emit `&"action_routing"` `{"person_id", "interaction_id", "target_id", "slot_index"}`.
- Starting to perform (`QUEUED` step 1 and `ROUTING` arrival): snap `person.pos` to the
  slot cell centre (`Vector2(x + 0.5, y + 0.5)`), then exactly as T-0006 does now: state
  `PERFORMING`, `slot_index`, `started_tick`, `facing` from the slot, emit `action_started`.
- `QUEUED` front action, in `step()`:
  1. If `slot_at_person()` is ≥ 0 and that slot is not taken → start performing on it.
  2. Otherwise choose a route (above).
- `ROUTING` front action, in `step()`, checked in this order:
  1. the person has a non-zero `move_intent` → cancel with reason `"moved"` (the player
     took over; `SetMoveIntentCommand` has already cleared the path, T-0004);
  2. arrived (path empty and `person.cell()` == the slot cell) → start performing;
  3. path empty but not arrived (e.g. after `path_blocked`) → choose a route again (it may
     pick another slot, or fail with `"no_free_slot"` / `"no_path"`). No retry counter is
     stored.
- `PERFORMING` front action + non-zero `move_intent` → cancel with reason `"moved"`.
- Failing: pop the front action and emit `&"action_failed"`
  `{"person_id", "interaction_id", "reason"}` (as T-0006 does). Cancelling: pop it and emit
  `&"action_cancelled"` `{"person_id", "interaction_id", "reason"}` (the same shape as
  `CancelActionCommand`). Failing or cancelling a `ROUTING` action also clears
  `person.path`.
- Remove the `not_at_slot` failure (walking replaces it). In `tests/sim/test_actions.gd`,
  replace `test_not_on_slot_fails_and_queue_moves_on` with a test that a slot with no route
  fails with `no_path` and the next queued action then starts. Keep every other T-0006 test
  passing unchanged.

## Acceptance criteria (`tests/sim/test_action_routing.gd` unless named)
Extra people for tests: `Person.new()`, `id = sim.world.new_id()`, `pos` at a cell centre,
needs filled from `content().needs` (each `need_def.start`), then `sim.world.add_person(p)`.
- [ ] Queue grab_snack from across the room → the person walks to the fridge slot, performs,
  finishes; the event order is queued → routing → started → finished, and the person ends on
  the slot cell centre facing the fridge.
- [ ] Two people queue sleep on a double bed: they use different slots. A third person
  queuing TV while the only TV slot is taken fails with `no_free_slot`.
- [ ] A slot behind a wall with no route → `no_path` (and the replaced test in
  `test_actions.gd`: the next queued action starts afterwards).
- [ ] A non-zero `SetMoveIntentCommand` during routing or performing cancels with reason
  `moved`, and the person stops following the path (the path is empty).
- [ ] An object placed on the route mid-walk (→ `path_blocked`) makes the action route again
  and still finish.
- [ ] Queue of three actions at different objects completes in order without intervention.
- [ ] Save during routing, load, continue = uninterrupted run (compare `SaveCodec.to_json`;
  assert the save really is mid-route: state `ROUTING` and a non-empty path).
- [ ] Property test: 3 people with random queues over 2 game hours never share a slot at the
  same time (check every minute; use a `RandomNumberGenerator` with a fixed seed in the
  test).
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
