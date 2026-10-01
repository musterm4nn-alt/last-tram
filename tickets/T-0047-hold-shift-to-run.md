---
id: T-0047
title: Hold Shift to run
status: done
milestone: M1
size: S
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
From the owner's M1 playtest: "add the ability to walk faster". Holding Shift makes the
player run at twice the walking speed: with WASD, and on click-to-walk routes and walks to
an object. Letting go goes back to walking. Running is person state, so NPCs can run later
(fleeing, chases in M4).

## Read first
- `docs/cookbook.md` → "Add a Command", "Add a field to Person", "Add a key binding"
- `sim/systems/movement_system.gd`, `sim/commands/set_move_intent_command.gd`,
  `game/input/player_controller.gd`, `tests/game/test_input_sync.gd`

## Scope
Create `sim/commands/set_running_command.gd`, `tests/sim/test_running.gd`. Change
`sim/people/person.gd`, `sim/systems/movement_system.gd`, `sim/core/command_registry.gd`,
`sim/save/save_validator.gd`, `sim/save/save_person_validator.gd`,
`game/input/input_actions.gd`, `game/input/player_controller.gd`, `game/ui/hud.gd`,
`tests/game/test_input_sync.gd`.
**Out of scope:** running tiring you out (energy cost), a running animation, NPCs choosing to
run.

## Specification
- `Person.running: bool = false` (saved as `"running"`; old saves → false, no version bump).
  `const RUN_FACTOR: float = 2.0`. `func move_speed() -> float`: `walk_speed * RUN_FACTOR`
  when running, else `walk_speed`.
- `MovementSystem.step` uses `person.move_speed()` for both direct movement and paths.
- `SetRunningCommand(person_id: int, running: bool)`, type id `"set_running"`, registered
  and validated (`running` boolean) in pending commands.
- Input action `"run": [KEY_SHIFT]`. `PlayerController` sends `SetRunningCommand` only when
  the held state changes, and again after `reset()` (load). No running while a menu is open.
- HUD hints: "Shift run" in both modes.

## Acceptance criteria
- [x] Running covers `walk_speed * 2` cells per minute with WASD and along a path; walking
  speed is unchanged → `test_running.gd`.
- [x] `running` survives save/load; an old save without it loads as walking →
  `test_running.gd`.
- [x] The controller sends one command when Shift goes down, one when it comes up, none while
  it is held, and re-sends after a load → `test_input_sync.gd`.
- [x] Running into a wall still stops before it (no tunnelling) → `test_running.gd`.
- [x] `tools/check.sh` passes.

## Implementation notes
- `Person.running` + `RUN_FACTOR = 2.0` + `move_speed()`; MovementSystem uses `move_speed()`
  for direct control and paths. Saved as `"running"` (read with default false, validated as
  a boolean), so v3 saves load as walking without a version bump.
- `SetRunningCommand` (`sim/commands/set_running_command.gd`), registered and validated in
  pending commands. Like `SetFreeWillCommand`, it doesn't count as input for the idle wait.
- `PlayerController` reads the `run` action (Shift) in both modes, except while a menu is
  open, and sends a command only on change or after `reset()`. The four existing input-sync
  assertions that counted "1 pending command" now count `set_move_intent` and
  `set_running` separately (a load now syncs both; same strength).
- HUD hint lines gain "Shift run".
- Verified: `tools/check.sh` 331 passed, 0 failed. Mutation checks: using `walk_speed` in
  MovementSystem fails both speed tests; dropping the controller's change check fails the
  "none while held" test. Screenshot `out/t0047.png`: the hint line fits at 1280×720.
- Self-reviewed by the architect (the owner asked Opus to build tickets directly).

## Questions

## Review feedback
