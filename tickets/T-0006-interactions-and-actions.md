---
id: T-0006
title: Interactions and the action lifecycle (queue, perform, finish, cancel)
status: todo
milestone: M1
size: L
owner: builder
depends_on: [T-0001, T-0005]
builder:
review_rounds: 0
---

## Goal
People can **do things with objects**: queue an interaction ("Sleep" on the bed, "Grab a
snack" from the fridge), perform it over game minutes while needs change, finish it, or
cancel it. In this ticket the person must already stand on a use slot; walking there comes
in T-0007.

## Read first
- `docs/design/actions-and-autonomy.md` (whole file; this ticket implements "Interactions",
  "Actions (runtime)" steps 2–3, and the queue)
- T-0001 (`ObjectDef`, `WorldObject`, slots) and T-0005 (needs) as merged in `main`
  (needs, as merged: `person.needs: Dictionary[String, float]`, `ContentDB.needs` /
  `ContentDB.need(id)` which returns null for an unknown id, `NeedsSystem` in
  `sim/systems/needs_system.gd`; `ContentDB` loads needs before the world, so validate
  interaction need ids with `need(id) != null`)
- `docs/cookbook.md` → "Add a new kind of content", "Add a Command", "Add a system"

## Scope
Create:
- `data/interactions/basics.json`
- `sim/content/interaction_def.gd`, `sim/content/interaction_loader.gd` (`InteractionLoader`,
  the T-0022 loader pattern: `load_interactions(r: ContentReader, dir: String)`, called from
  `ContentDB.load_from()` after the objects)
- `sim/actions/action.gd`, `sim/actions/interactions.gd`
- `sim/systems/action_system.gd`
- `sim/commands/queue_interaction_command.gd`, `sim/commands/cancel_action_command.gd`
- `tests/sim/test_actions.gd`

Change: `ContentDB` (field, query, one `load_from()` line), `Person` (queue, saved), `CommandRegistry`, `Sim.default_systems()`,
`game/ui/debug_overlay.gd` (show the player's action queue).
**Out of scope:** walking to slots, slot reservation and direct-input cancelling (T-0007);
menus and UI (T-0010); autonomy (T-0012).

## Specification

### Data: `data/interactions/basics.json` (load every file in `data/interactions/`)
```json
{ "interactions": [
	{ "id": "sleep", "name": "Sleep", "object_tags": ["bed"],
	  "until_need": "energy", "min_minutes": 60, "max_minutes": 720,
	  "need_rates": { "energy": 16.0 }, "finish_needs": {},
	  "advertise": { "energy": 80 } },
	{ "id": "grab_snack", "name": "Grab a snack", "object_tags": ["fridge"],
	  "duration_minutes": 5, "need_rates": {},
	  "finish_needs": { "hunger": 25 }, "advertise": { "hunger": 25 } },
	{ "id": "watch_tv", "name": "Watch TV", "object_tags": ["tv"],
	  "duration_minutes": 60, "need_rates": { "fun": 25.0, "comfort": -2.0 },
	  "finish_needs": {}, "advertise": { "fun": 25 } },
	{ "id": "sit", "name": "Sit down", "object_tags": ["seat"],
	  "duration_minutes": 30, "need_rates": { "comfort": 30.0 },
	  "finish_needs": {}, "advertise": { "comfort": 30 } }
] }
```
Give `sofa` the tag `"seat"` in `furniture.json` if T-0001 didn't.
Rules: exactly one of `duration_minutes` or `until_need` (with `min_minutes` and
`max_minutes`). All need ids must exist; all `object_tags` must be used by at least one
object; `need_rates` are per game hour and apply **on top of** normal decay.

### Classes
```gdscript
class_name InteractionDef extends RefCounted
var id: String; var name: String; var object_tags: PackedStringArray
var duration_minutes: int          # 0 when until_need is used
var until_need: String             # "" when duration_minutes is used
var min_minutes: int; var max_minutes: int
var need_rates: Dictionary[String, float]
var finish_needs: Dictionary[String, float]
var advertise: Dictionary[String, float]

class_name Action extends RefCounted   # saved inside Person.action_queue
const QUEUED := "queued"; const ROUTING := "routing"; const PERFORMING := "performing"
var interaction_id: String; var target_id: int
var slot_index: int = -1; var state: String = QUEUED
var minutes_done: int = 0; var started_tick: int = -1
func to_dict() -> Dictionary; static func from_dict(d: Dictionary) -> Action

class_name Interactions extends RefCounted   # static queries
## Interactions the target object offers (via its tags), in content order.
static func offered_by(sim: Sim, object_id: int) -> Array[InteractionDef]
## Index of the use slot `person` stands on for this object, or -1.
static func slot_at_person(sim: Sim, person: Person, object_id: int) -> int
```
`ContentDB.interactions: Dictionary[String, InteractionDef]` (+ `interaction(id)`).

### Person
`action_queue: Array[Action]` (saved; default `[]` on load). The front action (index 0) is
the current one. `MAX_QUEUE := 6`.

### Commands
- `QueueInteractionCommand(person_id, interaction_id, target_id)`, type `"queue_interaction"`:
  ignored unless the person and object exist, the object offers that interaction, and the
  queue has room. Appends an `Action`, then emits `&"action_queued"`
  `{"person_id", "interaction_id", "target_id"}`.
- `CancelActionCommand(person_id, index)`, type `"cancel_action"`: removes that action; emits
  `&"action_cancelled"` `{"person_id", "interaction_id", "reason": "player"}`.

### ActionSystem (`step()` and `on_minute()`)
- `step()`: for each person whose front action is `QUEUED`:
  `slot = Interactions.slot_at_person(...)`. If ≥ 0 → `state = PERFORMING`,
  `slot_index = slot`, `started_tick = tick`, set `facing` to the slot facing, and emit
  `&"action_started"`. Otherwise **fail**: pop it and emit `&"action_failed"`
  `{"person_id", "interaction_id", "reason": "not_at_slot"}` (T-0007 replaces this with
  walking).
- `on_minute()`: for each person whose front action is `PERFORMING`: apply
  `need_rates[n] / 60` to each need (clamped 0..100); `minutes_done += 1`; then check the end:
  fixed → `minutes_done >= duration_minutes`; until_need → (`need >= 100` and
  `minutes_done >= min_minutes`) or `minutes_done >= max_minutes`. On end: add `finish_needs`
  (clamped), pop, and emit `&"action_finished"`
  `{"person_id", "interaction_id", "minutes": minutes_done}`.
- Order: `[ActionSystem, MovementSystem, NeedsSystem]`.

## Acceptance criteria (`tests/sim/test_actions.gd`)
Build worlds with `from_rows` and `world.add_object()`; place the person on a slot by setting
`pos` in the test.
- [ ] Sleep on a bed from energy 20: runs until energy is 100 (≥ min_minutes), then
  finishes; the event sequence is queued → started → finished.
- [ ] grab_snack takes exactly 5 minutes and adds 25 hunger at the end.
- [ ] Rates stack with decay: after 60 min of watch_tv, fun changed by (+25 − 6).
- [ ] Not on a slot → `action_failed` with reason `not_at_slot`; the queue moves on to the next
  action.
- [ ] Queue limit 6; invalid commands (wrong interaction for the object, unknown ids) are
  ignored.
- [ ] Cancelling the front action while performing stops it (no more need changes), and the
  next action starts.
- [ ] Save while performing, load, continue = uninterrupted run (`test_save.gd` pattern).
- [ ] Content validation errors for: unknown need in `need_rates`, both or neither of
  `duration_minutes`/`until_need`, a tag no object uses.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
