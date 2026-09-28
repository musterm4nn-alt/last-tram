---
id: T-0015
title: Replay a session headless from a start save and a command log
status: done
milestone: M1
size: M
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Given a **start save**, the **commands** applied since then (with their ticks) and an **end
save**, a headless tool replays the commands on the start save and checks it arrives at
exactly the end save, or prints the first difference. This is the core of the owner's F9 bug
reports (the in-game F9 key is T-0024): an agent can reproduce any bug the owner hits.

## Read first
- `docs/architecture.md` → "Determinism", "Input: Commands"
- `sim/sim.gd` (`submit`, `step`, `take_applied_commands()`: each entry is
  `{"tick": <clock.tick when applied>, "command": <CommandRegistry.encode(...)>}`),
  `sim/save/save_codec.gd`, `sim/core/command_registry.gd`
- `tools/simrun.sh` and `tools/sim_runner.gd` (how a headless tool script is written)

## Scope
Create `sim/save/replay.gd` (`Replay`), `tools/replay_files.gd` (`ReplayFiles`),
`tools/replay.gd`, `tools/replay.sh`, `tests/sim/test_replay.gd`.
**Out of scope:** the F9 key, writing bug-report folders, and Session changes (T-0024).

## Specification

### Why pending commands are dropped
A save stores commands that were queued but not yet applied (`pending_commands`). When the
game applies them, they are logged like any other command. So a replay **empties the start
save's `pending_commands`** and submits every logged command at its tick instead; otherwise
they would run twice.

### `Replay` (`extends RefCounted`, static functions, pure: no files)
```gdscript
## Loads `start` (a save dictionary) with its pending commands removed, then steps until
## clock.tick == end_tick, submitting each logged command (in log order) just before the
## step whose starting tick equals the entry's "tick". Returns null (and fills `errors`) if
## the start save does not load, an entry has an unknown command type, or an entry's tick is
## before the start tick or not before end_tick.
static func run(start: Dictionary, commands: Array, end_tick: int, content: ContentDB,
		errors: Array[String] = []) -> Sim

## "" if `a` and `b` are equal; otherwise the path and both values of the first difference,
## e.g. 'world.people[0].pos[0]: expected 12.5, got 12.75'. Dictionaries: compare sorted
## keys (a missing key is a difference); arrays: length first, then items in order; numbers
## compare exactly (floats included: determinism means bit-identical).
static func first_difference(expected: Variant, actual: Variant, path: String = "") -> String

## Replays and compares with `end` (a save dictionary), ignoring "pending_commands" on both
## sides. Returns "" when the replay reproduces the end save, otherwise a message
## (the load error, or first_difference()).
static func check(start: Dictionary, commands: Array, end: Dictionary, content: ContentDB) -> String
```
Round-trip both sides through JSON before comparing (`JSON.parse_string(Ser.to_json(...))`
for the replayed sim, the parsed file for the end save), so ints and floats compare the same
way on both sides.

### Reading a report folder: `ReplayFiles` (`tools/replay_files.gd`, `extends RefCounted`)
Files are read here, not in `sim/` (only `sim/content/` may read files).
```gdscript
## Reads <folder>/start.json, commands.json (a JSON array of log entries) and end.json, and
## replays them. Returns {"status": "OK" | "MISMATCH" | "ERROR", "message": String,
## "commands": int, "steps": int}; ERROR when a file is missing or not valid JSON.
static func check_folder(folder: String, content: ContentDB) -> Dictionary
```
`end.json`'s clock tick is the end tick; `steps` = end tick − start tick.

### Tool: `tools/replay.sh <folder>`
- `<folder>` holds the files T-0024 will write. `tools/replay.sh` runs
  `godot --headless --path . --script res://tools/replay.gd -- <folder>` like
  `tools/simrun.sh` does; `tools/replay.gd` calls `ReplayFiles.check_folder`.
- Prints, in plain words: `REPLAY OK: 12 commands over 5400 steps reproduce the end save.`
  or `REPLAY MISMATCH: <message>`, or `REPLAY ERROR: <what is missing or broken>`; the last
  line is `LAST_TRAM_REPLAY: OK` / `MISMATCH` / `ERROR`, and the exit code is 0 only for OK.

## Acceptance criteria (`tests/sim/test_replay.gd`)
Build the input like the game will: a sim from `SimFactory.from_rows`, `start =
SaveCodec.to_dict(sim)`, then submit commands (a `SetMoveIntentCommand` and a
`WalkToCommand`) at different ticks while stepping, collecting
`sim.take_applied_commands()`, and finally `end = SaveCodec.to_dict(sim)`.
- [ ] `Replay.check(start, log, end, content())` is `""` for a recorded run of at least 2 game
  hours with at least 3 commands.
- [ ] A command queued (pending) in the start save is not applied twice: submit one, take
  `start` before stepping, and the replay still matches.
- [ ] Changing one logged command (another direction) gives a mismatch whose message names
  a path under `world.people`.
- [ ] `first_difference`: equal nested values → ""; a changed float, a missing key and a
  longer array each give the path of the difference.
- [ ] Bad input gives errors, not crashes: an unknown command type, a tick before the start,
  a start that is not a save.
- [ ] `ReplayFiles.check_folder`: a test writes a recorded run's three files into
  `user://test_replay_t0015/` (deleted afterwards): status "OK" with the right command and
  step counts; with one number changed in end.json, "MISMATCH" and the path in the message;
  with commands.json missing, "ERROR".
- [ ] Manual check (write the commands you ran in the notes): write the three files of a
  recorded run into `out/replay_demo/` (a few lines in a scratch script are fine), then
  `tools/replay.sh out/replay_demo` prints `REPLAY OK` and exits 0; after editing one number
  in `end.json` it prints `REPLAY MISMATCH` with that path and exits non-zero.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- `sim/save/replay.gd` (`Replay`): `run()` (start without pending commands, logged commands
  submitted at their ticks, input checked: shape, range, order, known type), `first_difference()`,
  `check()`, plus two small helpers the file reader shares: `compare(sim, end)` and
  `end_tick_of(save)`.
- `tools/replay_files.gd` (`ReplayFiles.check_folder`), `tools/replay.gd`, `tools/replay.sh`
  (exit 0 only for OK).
- Tests: `tests/sim/test_replay.gd` (6). A mutation check caught a weak spot in my own first
  version: the pending-command test's recording also pressed a key that cancelled both
  snacks, which hid a double application. It now records a clean run, and keeping the
  pending commands fails it. Submitting commands one tick late fails four tests.
  `tools/check.sh`: 253 passed, 0 failed.
- Manual check (a scratch script wrote a 4-hour recording with free will and one WalkTo to
  `out/replay_demo/`): `tools/replay.sh out/replay_demo` → `REPLAY OK: 1 command over 4800
  steps reproduce the end save.` (exit 0); after setting fun to 12.5 in end.json →
  `REPLAY MISMATCH: world.people[0].needs.fun: expected 12.5, got 56.0000000000008` (exit 1);
  without commands.json → `REPLAY ERROR: commands.json is missing.` (exit 1).

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
