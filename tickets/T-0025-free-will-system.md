---
id: T-0025
title: Free will: the idle player looks after their own needs (on/off in the Esc menu)
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0012, T-0023]
builder:
review_rounds: 0
---

## Goal
When you leave your character alone for a while (no input for 10 game minutes) and their
queue is empty, they look after themselves: they pick something sensible to do with
T-0012's scoring and do it. Free will is on by default; the Esc menu has a "Free will: On /
Off" button. Whatever you do yourself always wins.

## Read first
- `docs/design/actions-and-autonomy.md` → "Control modes" (Free will), "Autonomy"
- T-0012 as merged: `Autonomy.candidates(sim, person)`, `Autonomy.choose(options, rng)`
- As merged: `sim/sim.gd` (`default_systems()`; D23 order), `sim/systems/needs_system.gd`
  (a system using `on_minute`), `sim/actions/action.gd`, the four player commands in
  `sim/commands/`, `sim/people/person.gd` (saving a field with a default)
- T-0023 as merged: `game/ui/pause_menu.gd` (`PauseMenu`, its main page buttons)
- The architect prototyped exactly this spec with T-0011's content before writing it
  (seed 1, 3 game days, no input): every need stayed above 40, and the player used every
  object (sit 25×, TV 16, cook 8, sleep 7, calls 7, showers 7, snacks 4, web 2, naps 2).
  If your one-day test fails, suspect the code before the content.

## Scope
Create `sim/systems/autonomy_system.gd` (`AutonomySystem`),
`sim/commands/set_free_will_command.gd` (`SetFreeWillCommand`), `tests/sim/test_free_will.gd`.
Change `sim/sim.gd` (system order), `sim/people/person.gd` (two saved fields),
`sim/core/command_registry.gd`, `sim/commands/set_move_intent_command.gd`,
`sim/commands/walk_to_command.gd`, `sim/commands/queue_interaction_command.gd`,
`sim/commands/cancel_action_command.gd` (each records the input tick),
`game/ui/pause_menu.gd` (the toggle), `game/ui/debug_overlay.gd` (one line),
`tests/game/test_pause_menu.gd` (the toggle).
**Out of scope:** NPCs (M2), a settings screen, moods and personality in scoring.

## Specification

### Person (both saved; read with the default when missing, so old saves load)
```gdscript
## Free will: when idle for a while, the person looks after their own needs (T-0025).
var free_will: bool = true
## Tick of the last direct input (a player command) for this person; autonomy waits
## AutonomySystem.IDLE_MINUTES after it.
var last_input_tick: int = 0
```

### Input tick
`SetMoveIntentCommand`, `WalkToCommand`, `QueueInteractionCommand` and
`CancelActionCommand` set `person.last_input_tick = sim.clock.tick` in `apply()` as soon as
the person is found (even if the rest of the command is then ignored). `SetFreeWillCommand`
does not.

### `SetFreeWillCommand(person_id: int, enabled: bool)`, type `"set_free_will"`
Sets `person.free_will`; ignored for an unknown person. Registered in `CommandRegistry`.

### `AutonomySystem` (`extends SimSystem`, `on_minute` only, no state)
```gdscript
## Game minutes without input before autonomy may act for a person.
const IDLE_MINUTES: int = 10
```
For each person (dictionary order) with `free_will`, an empty `action_queue`, an empty
`path`, a zero `move_intent`, and
`sim.clock.tick - person.last_input_tick >= IDLE_MINUTES * SimClock.STEPS_PER_GAME_MINUTE`:
`var choice := Autonomy.choose(Autonomy.candidates(sim, person), sim.rng.stream("autonomy"))`;
if it is not empty, append `Action.new(choice["interaction_id"], choice["object_id"])` to the
queue and emit `&"autonomy_chose"` `{"person_id", "interaction_id", "target_id", "score"}`.
The ActionSystem routes it on the next step (T-0007).
`Sim.default_systems()` becomes `[ActionSystem, MovementSystem, NeedsSystem, AutonomySystem]`
(autonomy decides after the minute's needs have changed).

### Game
- `PauseMenu` main page: a button between Load game and Quit game, text
  `"Free will: On"` / `"Free will: Off"` from the player's current `free_will`; pressing it
  submits `SetFreeWillCommand.new(player.id, not player.free_will)` and updates the text at
  once (the command applies on the next step, but the menu shows the chosen state).
- Debug overlay: a line `  free will on (idle 3 min)` / `  free will off`, where idle is the
  whole game minutes since `last_input_tick`.

## Acceptance criteria (`tests/sim/test_free_will.gd` unless named)
Use `SimFactory.new_game(content(), 1)` (the furnished flat) unless said otherwise.
- [ ] A hungry idle player (hunger 20, everything else 100, no input) gets an
  `autonomy_chose` for grab_snack or cook_meal within the first 11 game minutes, walks there,
  and ends with more hunger than they started with after 60 game minutes.
- [ ] With `SetFreeWillCommand(player, false)`, the same player queues nothing in 2 game hours.
- [ ] Input holds autonomy back: a zero `SetMoveIntentCommand` at minute 0 → nothing chosen
  before minute 10, something chosen by minute 11. Each of the four player commands sets
  `last_input_tick`.
- [ ] A content player (all needs 100) chooses nothing for an hour.
- [ ] Autonomy never adds to a non-empty queue (queue one action yourself, run: no
  `autonomy_chose` until it is done).
- [ ] Save after 90 minutes of autonomy, load, run 90 more = one uninterrupted 180-minute
  run (`SaveCodec.to_json` equal); `free_will` and `last_input_tick` round-trip, and a save
  without them loads with the defaults.
- [ ] One game day from a new game with free will on and no input: no need ever reaches 0
  (check every minute; print the minimum of each need in the test output).
- [ ] `test_commands.gd` covers `set_free_will` registration and round trip (it does so
  automatically once registered; check it passes).
- [ ] `tests/game/test_pause_menu.gd`: the button shows "Free will: On" for a new player and,
  when pressed, submits `SetFreeWillCommand` with `false` and shows "Free will: Off".
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
