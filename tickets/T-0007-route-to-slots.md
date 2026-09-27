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
- `sim/systems/action_system.gd` (T-0006) and `sim/systems/movement_system.gd` (T-0004)

## Scope
Change `sim/systems/action_system.gd`, `sim/actions/interactions.gd`, and tests
(`tests/sim/test_actions.gd`, or a new `tests/sim/test_action_routing.gd`).
**Out of scope:** UI (T-0010), autonomy (T-0012).

## Specification
- Slots are **reserved implicitly**: a slot counts as taken if any *other* person's front
  action targets the same object with the same `slot_index` and is `ROUTING` or
  `PERFORMING`. Add `Interactions.slot_taken(sim, object_id, slot_index, except_person_id)
  -> bool` (it scans people; there's no extra saved state).
- `QUEUED` front action, in `step()`:
  1. If the person already stands on a free slot of the target → `PERFORMING` (as in T-0006).
  2. Otherwise, for each free slot whose cell is walkable, compute
     `sim.nav.find_path(person.cell(), slot_cell)` (T-0003: the cells after the start, empty
     if unreachable) and ignore empty results. Pick the **shortest path** by `path.size()`
     (ties: lowest slot index). Set `slot_index`, `person.path` to that path, and
     `state = ROUTING`; emit `&"action_routing"`.
  3. If no free slot → fail with reason `"no_free_slot"`; if no path to any free slot →
     reason `"no_path"`.
- `ROUTING` front action, in `step()`, checked in this order:
  1. the person has a non-zero `move_intent` → cancel with reason `"moved"` (the player
     took over; `SetMoveIntentCommand` has already cleared the path, T-0004);
  2. arrived (path empty and `person.cell()` == slot cell) → snap `pos` to the cell centre →
     `PERFORMING` (emit `action_started`);
  3. path empty but not arrived (e.g. after `path_blocked`) → route again exactly like
     `QUEUED` step 2 (it may pick another slot); if that finds no free slot or no path, fail
     with `"no_free_slot"` or `"no_path"`. No retry counter is stored.
- `PERFORMING` front action + non-zero `move_intent` → cancel with reason `"moved"`.
- Cancelling or failing a `ROUTING` action clears `person.path`.
- Remove the `not_at_slot` failure from T-0006 (walking replaces it) and update its test.

## Acceptance criteria
- [ ] Queue grab_snack from across the room → the person walks to the fridge slot, performs,
  finishes; the event order is queued → routing → started → finished.
- [ ] Two people queue sleep on a double bed: they use different slots. A third person
  queuing TV while the only TV slot is taken fails with `no_free_slot`.
- [ ] A slot behind a wall with no route → `no_path`.
- [ ] A non-zero `SetMoveIntentCommand` during routing or performing cancels with reason
  `moved`, and the person stops following the path.
- [ ] Queue of three actions at different objects completes in order without intervention.
- [ ] Save during routing, load, continue = uninterrupted run.
- [ ] Property test: 3 people with random queues over 2 game hours never share a slot at the
  same time (check every minute).
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
