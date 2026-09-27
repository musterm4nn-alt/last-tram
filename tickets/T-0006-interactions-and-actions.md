---
id: T-0006
title: Interactions and the action lifecycle (queue, perform, finish, cancel)
status: done
milestone: M1
size: L
owner: builder
depends_on: [T-0001, T-0005]
builder: OpenCode / Muse Spark
review_rounds: 1
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
- Use slots, as merged (T-0001): `WorldObject.slot_count(content) -> int`,
  `slot_cell(content, index) -> Vector3i` and `slot_facing(content, index) -> Vector2i`
  (a person's `facing` is a `Vector2`: `person.facing = Vector2(obj.slot_facing(...))`).
  `world.get_object(id)` returns null for an unknown id.
- `docs/cookbook.md` → "Add a new kind of content", "Add a Command", "Add a system"

## Scope
Create:
- `data/interactions/basics.json`
- `sim/content/interaction_def.gd`, `sim/content/interaction_loader.gd` (`InteractionLoader`,
  the T-0022 loader pattern: `static func load(db: ContentDB, reader: ContentReader, dir:
  String)`, called from `ContentDB.load_from()` after the objects, plus
  `static func load_file(db, reader, path)` for one file, exactly like `ObjectLoader`)
- `tests/fixtures/content_broken/interactions/broken.json` (deliberately bad entries for the
  validation tests). Load it with `InteractionLoader.load_file` into a **fresh**
  `ContentDB.load_default()` and a new `ContentReader`, never into the shared `content()`
  that every test uses.
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
  finishes; the event sequence is queued → started → finished. (NeedsSystem runs after
  ActionSystem in the same minute, so just after the finish energy is a hair under 100:
  assert `>= 99.9`, and that `action_finished` reports `minutes >= 60`.)
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

Implemented the interaction/action lifecycle exactly per spec. Key files:

- `data/interactions/basics.json` — sleep (until energy, 60–720 min), grab_snack,
  watch_tv, sit, with the exact ids/rates from the ticket. `sofa` already had the
  `"seat"` tag in `furniture.json`, so no change was needed there.
- `sim/content/interaction_def.gd` (`InteractionDef`) + `sim/content/interaction_loader.gd`
  (`InteractionLoader` with `load(db, reader, dir)` / `load_file(db, reader, path)`,
  wired into `ContentDB.load_from()` after objects). Validates: exactly one of
  `duration_minutes` / `until_need` (+ sane min/max), every need id exists
  (`need_rates`, `finish_needs`, `advertise`, `until_need`), every `object_tags`
  entry is used by at least one object.
- `sim/actions/action.gd` (`Action`, saved inside `Person.action_queue`) +
  `sim/actions/interactions.gd` (static `offered_by` in content order,
  `slot_at_person` comparing full cells incl. level).
- `sim/commands/queue_interaction_command.gd` (`queue_interaction`) and
  `sim/commands/cancel_action_command.gd` (`cancel_action`), both registered in
  `CommandRegistry`. Invalid commands are ignored silently (no events).
- `sim/systems/action_system.gd` (`ActionSystem`): `step()` starts a QUEUED front
  action when the person stands on a use slot (sets facing, emits
  `action_started`), else pops it with `action_failed`/`not_at_slot`; `on_minute()`
  applies `need_rates/60`, counts minutes, ends fixed actions at
  `duration_minutes` and until_need actions at need 100 (after min) or max, then
  applies `finish_needs` and emits `action_finished` with `minutes`.
- `Person.action_queue` + `MAX_QUEUE = 6`, saved/loaded (defaults to `[]`, so old
  saves load without a version bump). `Sim.default_systems()` is now
  `[ActionSystem, MovementSystem, NeedsSystem]` with an order comment.
- `game/ui/debug_overlay.gd` shows the player's action queue (`id [state]`).
- `tests/sim/test_actions.gd` (10 tests) + broken fixture
  `tests/fixtures/content_broken/interactions/broken.json` (unknown need,
  both/neither duration, unused tag), loaded via `load_file` into a fresh
  `ContentDB.load_default()` + new `ContentReader`.

Verification: `tools/check.sh` → 158 passed, 0 failed (10 new action tests
included). Sleep from energy 20 finishes at minute 418 with energy 99.925
(>= 99.9); grab_snack finishes at exactly 5 min with hunger 74.5
(50 − 0.5 + 25); watch_tv over 60 min nets fun +19 and comfort −10. No
screenshot: no visible game change (sim-only; the debug-overlay line is F3-only).
Out of scope as specified: routing/walking to slots (T-0007 does that), menus,
autonomy. One deliberate extra: unknown interaction/target defs fail with
`unknown_interaction` instead of hanging (unreachable with valid content).

## Questions

## Review feedback

**Round 1 (architect): passed, with test additions by the reviewer.** Built from the latest
`main` in a fresh OpenCode session started by the architect (Muse Spark 1.3 free, xhigh).
Clean, well-documented code that follows the spec closely; thorough content validation; the
`unknown_interaction` guard is a sensible extra; honest notes. A mutation check found gaps in
the tests, now closed:
- Added `test_sleep_runs_at_least_min_minutes_even_when_already_rested` and
  `test_sleep_stops_at_max_minutes_even_when_not_rested`: ignoring `min_minutes` or
  `max_minutes` passed every test before (sleep from energy 20 never reaches either limit).
- `test_broken_interactions_are_reported` only checked that the joined errors contained a
  few words, so dropping the "both" or the "neither" check, or the need-id check for
  `advertise` / `until_need`, still passed. It now checks one error per broken entry (by its
  id), and the fixture has one more entry with unknown needs in `until_need`,
  `finish_needs` and `advertise`.
- Ten mutations in all (min/max minutes, both/neither, advertise and until_need ids, facing,
  `minutes_done` not saved, `offered_by` ignoring tags...): each now fails a test.
- F3 screenshot (reviewer): the overlay shows "actions: (empty)" under the needs.
- Docs (architect): architecture folder map gains `actions/`, the system order is now
  actions → movement → needs (D23).
