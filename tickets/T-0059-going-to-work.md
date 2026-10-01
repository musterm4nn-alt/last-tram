---
id: T-0059
title: Going to work - the work action and the rabbit hole
status: done
milestone: M3
size: M
owner: builder
depends_on: [T-0058, T-0056]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Working becomes something you do. During your shift (from an hour before it starts), your
workplace offers "Work". For a city job that's the tram shelter on the Altmarkt: you take the
tram and disappear until the shift ends. For the police it's the desk in the Polizeiposten.
The game skips ahead while you work, like sleep, and your needs change the way the job says.
Shop staff work behind their counters (hidden for now; visible in T-0065). This is the first
`WorkSession`, the rabbit hole. Going on your own comes next (T-0060), and pay in T-0061.

## Read first
D10, D29 (work is an action); `docs/design/jobs-and-economy.md` → Jobs and careers;
`sim/systems/action_system.gd`, `sim/content/use_slot_def.gd`, `sim/actions/interactions.gd`,
`sim/ai/autonomy.gd` (`_cells_to_free_slot`), `sim/social/conversations.gd` (`available`),
`game/view2d/person_view_2d.gd`, `game/input/player_controller.gd` (`person_at`,
`nearest_person`), `game/ui/person_inspector.gd` (`doing`).

## Scope
Create `data/interactions/work.json`, `sim/jobs/work_session.gd`, `work_result.gd`,
`rabbit_hole_work.gd`, `work_sessions.gd`, `tests/sim/test_work.gd`.
Change `sim/content/use_slot_def.gd`, `object_loader.gd`, `interaction_def.gd`,
`interaction_loader.gd`, `data/objects/shops.json`, `workplaces.json`, `public.json`,
`data/world/districts/altstadt/objects.json` (the bar moves one row down),
`data/jobs.json` (bartender tag), `sim/actions/interactions.gd`, `requirements.gd`,
`sim/systems/action_system.gd`, `sim/ai/autonomy.gd`, `sim/jobs/jobs.gd`,
`sim/social/conversations.gd`, `game/view2d/person_view_2d.gd`,
`game/input/player_controller.gd`, `game/ui/interaction_menu.gd`, `person_inspector.gd`.
**Out of scope:** going to work by yourself and reminders (T-0060); pay and performance
(T-0061); visible staff and staffed counters (T-0065); saved shift state (nothing new is
saved: the work action holds it).

## Specification

### Slot roles
- `UseSlotDef.role: String` = "customer" (default) or "staff"; `ObjectLoader` reads the
  optional `"role"` and reports unknown roles.
- `Interactions.slot_fits(sim, object_id, slot_index, def) -> bool`: staff slots for work
  interactions, customer slots for everything else. `slot_at_person(sim, person, object_id,
  def = null)` and `ActionSystem._choose_route` only use fitting slots;
  `Autonomy._cells_to_free_slot` only customer slots (free will never chooses work).
- Staff slots: behind the Späti and Imbiss counters (offset [1,-1], facing [0,1]); the bar
  counter moves from (47,7) to (47,8) (customers at y 9, staff at (47..50, 7) facing down;
  `pub_table` at (51,9) is clear of it) and gets the tag `bar_counter` (the bartender's
  `workplace_tag`); the tram shelter's eight slots are all staff; the police desk's two back
  slots ([0,1], [1,1]) are staff.

### The work interaction (`data/interactions/work.json`)
`{"id": "work", "name": "Work", "work": true, "time_skip": true, "object_tags": ["tram_stop",
"police_desk", "spaeti_counter", "imbiss_counter", "bar_counter"], "need_rates": {},
"finish_needs": {}, "advertise": {}}`. `InteractionDef.work: bool`; the loader allows no
duration for work (and only for work).

### Requirements (in `Requirements.check`, first for work)
- `not_your_job`: no job, or the object lacks the job's `workplace_tag`, or isn't on the job's
  place. `Requirements.HIDDEN` lists it; the menu leaves hidden options out.
- `not_your_shift` ("not your shift"): unless `Jobs.shift_window(sim, person, tick)` finds a
  shift (today's, or yesterday's past midnight) with start − 60 min ≤ now < end.

### `WorkSession` (D10)
```gdscript
class_name WorkSession   # sim/jobs/work_session.gd: base class, no state
func begin(sim: Sim, person: Person, action: Action) -> void
func on_minute(sim: Sim, person: Person, action: Action) -> void
func finish(sim: Sim, person: Person, action: Action, completed: bool) -> WorkResult
func hidden() -> bool
```
- `WorkResult` (`work_result.gd`): `job_id`, `minutes` (worked inside the shift window),
  `late_minutes` (performing started after the shift start), `left_early` (not completed).
- `RabbitHoleWork`: `on_minute` applies the job's `need_rates` / 60 (clamped 0..100);
  `hidden()` true; `finish` fills a `WorkResult` from the action and the shift window.
- `WorkSessions.for_job(job: JobDef) -> WorkSession`: `rabbit_hole` → `RabbitHoleWork`;
  `on_site` → `RabbitHoleWork` until T-0065.
- `Jobs.shift_window(sim, person, tick) -> Vector2i` (the start and end ticks containing
  `tick`, with the hour of grace before; (-1, -1) for none), `Jobs.working(sim, person) ->
  bool` (performing work) and `Jobs.hidden(sim, person) -> bool` (working in a hidden
  session).

### ActionSystem
- `_start_performing` (work): after the requirements, `begin`, then emit `shift_started
  {person_id, job_id, late_minutes}`.
- `_progress` (work): `on_minute` each personal minute; the action ends when the clock reaches
  the end of the shift window it started in (or at once if the person lost the job).
- Ending a PERFORMING work action (finished, cancelled or failed) calls `finish(…, completed)`
  and emits `shift_ended {person_id, job_id, minutes, late_minutes, left_early}`.

### Hidden people
`PersonView2D` hides them; `PlayerController.person_at` and `nearest_person` skip them;
`Conversations.available` is false for them; `PersonInspector.doing` says "At work until
17:00".

## Acceptance criteria (`tests/sim/test_work.gd` unless named)
- [x] Slots: work routes to staff slots, buying to customer slots; free will ignores staff
  slots; content errors for an unknown role.
- [x] The player (office clerk) can queue Work at the tram shelter from 08:00 on Monday, not
  at 07:30, not on Saturday, not at the police desk (hidden); the menu shows Work only where
  it applies.
- [x] Working: arriving at 08:55 starts the shift (`shift_started`, late 0); the player is
  hidden and unavailable for a chat; needs follow the job's rates; at 17:00 the action ends
  (`shift_ended`, minutes 480) and the player stands at the shelter.
- [x] Leaving early: walking away at 12:00 ends it (`left_early`, minutes 180). Late: starting
  at 09:20 gives `late_minutes` 20.
- [x] A shift past midnight (the bartender, 17–2) ends at 02:00 the next day.
- [x] Saving mid-shift and loading continues identically (`SaveCodec.to_json` equal after
  running both).
- [x] `test_person_inspector.gd`: "Doing: At work until 17:00".
- [x] `tools/check.sh` passes; `--check-m2` passes on seeds 1–3 (nobody works by themselves
  yet). Screenshot `out/t0059.png`: the menu at the tram shelter with "Work".

## Implementation notes
- As specified. The work hooks live in `Jobs` (`start_shift`, `work_minute`, `shift_over`,
  `end_shift`) so `ActionSystem` only calls them. `CancelActionCommand` ends a performing
  shift too, since it removes actions without going through `ActionSystem._cancel`.
- `test_prices.gd`'s `BAR_SLOT` moved with the bar counter (47,8 → customers at y 9).
- Verified: `tools/check.sh` 527 passed, 0 failed (`test_work.gd`, 6 tests, plus inspector
  and content checks). `tools/simrun.sh --days=7 --check-m2` PASSED on seeds 1–3 (nobody
  works by themselves yet). Screenshot `out/t0059.png`: the tram shelter's menu with "Work"
  (opened while the camera was still moving, so it sits at the left).

## Questions

## Review feedback
