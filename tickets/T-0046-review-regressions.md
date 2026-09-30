---
id: T-0046
title: Fix the nine September 2026 code review regressions
status: done
milestone: M1
size: L
owner: builder
depends_on: []
builder: Codex / GPT-6
review_rounds: 1
---

## Goal

Fix all nine reproduced findings from the 2026-09-30 code review. The owner explicitly
requested a backup of current main, the fixes, and publication to main in this session.

## Scope

Save I/O and validation, save migration/fixture tooling, input synchronization, action
identity/movement/timing, sleep skipping, autosave recovery, world content readers and
their regression tests. No art, gameplay content or protected project documents changed.

## Acceptance criteria

- [x] R1: a short write or failed replacement reports failure and preserves the prior save.
- [x] R2: malformed save schemas return null with errors, without replacing a running game.
- [x] R3: load synchronizes current input before the first simulation step, through a command.
- [x] R4: an immediate walk cancels the current interaction; queued successors wait for the
  walk to finish. Absent targets or obsolete movement cannot grant interaction benefits.
- [x] R5: sleep completion, cancellation, replacement or a critical need stops the current
  frame's accelerated budget immediately.
- [x] R6: delayed cancel buttons address saved action instances, including repeated clicks
  and several clicks before the simulation resumes.
- [x] R7: durations and rates count full elapsed personal minutes at every clock phase.
- [x] R8: failed autosaves retain the daily marker, replay checkpoint and commands, then retry
  after a bounded cooldown when the destination recovers.
- [x] R9: malformed district/place/coordinate/level content reports contextual errors.
- [x] Version 3 has a fixture; unchanged v1/v2 fixtures and legacy index commands still load.
- [x] The full tests, architecture lint and startup smoke checks pass.

## Implementation notes

- Backup: `backup/main-2026-09-30-before-review-fixes`, at
  `d8672eecd50e12a1b676104d33c0be0dd36b1046`. It remains at the original main commit.
- `game/save_file.gd` writes and flushes a same-directory temporary file, checks the error
  and byte length, and replaces the destination only on success. Failure cleans up the
  temporary file. `Session` advances autosave/replay bookkeeping only after success;
  failed automatic attempts retry after ten real seconds.
- `sim/save/save_schema.gd`, `save_person_validator.gd` and `save_validator.gd` validate
  primitives, nested state, grids/base64, ids/references, RNG states and pending commands
  before deserialization. Removed content retains the existing compatibility fallbacks.
  A rejected load emits a notice and preserves the active Sim.
- Actions receive stable integer ids from the saved world allocator. Cancellation uses
  the captured id; the old index API remains supported. Save v2 -> v3 assigns ids to old
  queues. Earlier migrations and fixtures are unchanged. The new fixture includes an
  action and a pending cancellation.
- `PlayerController.reset()` submits the current input immediately on game_loaded;
  subsequent frames suppress unchanged input. Zero intent preserves click-to-walk paths.
- Immediate walk commands cancel the front action. Later queued actions wait while an
  immediate path/direct movement owns locomotion. Performing actions verify their target
  and slot, and grant rates/finish effects only after complete minutes since started_tick.
- Session checks the skipped action and forwards critical events after each step,
  discarding accelerated time when the action stops or changes. Applied commands are
  logged before event callbacks.
- WorldLoader uses typed coordinate readers and checks place entries, level keys and
  filenames before conversion. ContentReader rejects non-finite/fractional coordinates.

## Verification

- Godot 4.7.2, `tools/check.sh`: **321 passed, 0 failed**, including all original 285 tests,
  36 added regressions, every script compilation and all architecture/length lint.
- Fixed-seed duration/rate tests cover every one of the 20 possible minute phases,
  including mid-minute save/continue equality and sleep's minimum duration.
- Save failure tests exercise short writes, temporary-open failure, rename failure,
  corrupt loads and same-day autosave recovery. Replay.check proves the retained history
  reproduces the game after a failed autosave.
- Real OS fault injection: an existing 18,772-byte valid save, with child-process
  RLIMIT_FSIZE=1,024 and SIGXFSZ ignored. Saving returned ERR_FILE_CANT_WRITE (13), kept
  the old file byte-identical and valid, and removed the failed temporary file.
- `tools/simrun.sh --days=3 --seed=7 --report-every=1440`: **86,400 steps**,
  LAST_TRAM_SIMRUN: OK; all six needs spent 0% of sampled minutes below 30.
- Gameplay with a queued snack/TV, seeded clothes creator, pause menu and loading the
  v3 fixture: **60 headless frames each**, no script/runtime errors.
- No layout or art changes. Graphical screenshots were not captured: this environment
  has no display server. UI behavior is verified by headless button and startup tests.
- `git diff --check` passes. The repository's pre-commit hook is run before publication.

## Questions

None.

## Review feedback

Self-reviewed against all nine reproductions. Main publication is explicitly authorized
by the owner; the backup branch is retained for rollback.
