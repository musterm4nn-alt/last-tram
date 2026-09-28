---
id: T-0024
title: F9 writes a bug report that replays exactly
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0014, T-0015]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
When something goes wrong, the owner presses **F9**. The game writes a bug-report folder:
the save the current stretch of play started from, every command since then, the save right
now, a screenshot and a short info file. `tools/replay.sh <folder>` (T-0015) then reproduces
it exactly, so an agent can see the bug happen.

## Read first
- `docs/workflow.md` → "Reporting problems and wishes"
- T-0015 as merged: `sim/save/replay.gd` (`Replay.check(start, commands, end, content)`),
  `tools/replay_files.gd` (`ReplayFiles.check_folder(folder, content)`), `tools/replay.sh`
- As merged: `game/session.gd` (`command_log`, `_after_load()`, `_process()`, and T-0014's
  `autosave()`), `game/main.gd` (`_unhandled_input`, how the `--screenshot` option grabs the
  viewport image), `game/input/input_actions.gd`, `game/ui/hud.gd` (`hint_text`)

## Scope
Change `game/session.gd`, `game/main.gd`, `game/input/input_actions.gd`, `game/ui/hud.gd`
(hint line); create `tests/game/test_bug_report.gd`.
**Out of scope:** uploading reports, a report form, trimming old reports.

## Specification

### The replay start
- `Session` keeps `var _replay_start: String` (save JSON). `_after_load()` sets it to
  `SaveCodec.to_json(sim)` right after its existing drain/clear lines (so it matches the
  cleared `command_log`).
- `autosave()` (T-0014), after writing the autosave: `_replay_start = SaveCodec.to_json(sim)`
  and `command_log.clear()` (the next report starts from the autosave). Make sure
  `_process()` appends `sim.take_applied_commands()` to `command_log` **before** it checks
  for the autosave, so no applied command is lost.

### Writing a report
```gdscript
## Where reports go (tests pass their own folder).
const BUG_REPORT_DIR: String = "user://bug_reports"
## Writes <base_dir>/<YYYY-MM-DD_HH-MM-SS>/ with start.json (_replay_start), commands.json
## (command_log as a JSON array, Ser.to_json), end.json (SaveCodec.to_json(sim)),
## screenshot.png (if `screenshot` is not null) and info.txt. Returns the folder's absolute
## path (ProjectSettings.globalize_path), or "" if writing failed.
func write_bug_report(screenshot: Image, base_dir: String = BUG_REPORT_DIR) -> String
```
`info.txt`, plain text: the real date and time, the in-game day and time
(`clock.day() + 1`, `clock.format()`), the player's name and cell, the speed, the number of
commands, and the last 20 events from `sim.events.recent` (one per line:
`<tick> <type> <data>`). If a folder with that name exists, append `_2`, `_3`...

### F9
- `InputActions.KEYS`: `"bug_report": [KEY_F9]`.
- `main.gd` `_unhandled_input`: on `bug_report`, grab `get_viewport().get_texture().get_image()`,
  call `Session.write_bug_report(image)`, `print()` the folder path, and show the notice
  `"Bug report saved: <folder name>"` (or `"Bug report failed"`).
- `Hud.hint_text()` gains `"F9 report a bug"` (both modes).

## Acceptance criteria (`tests/game/test_bug_report.gd`)
Swap `Session.sim` / `content` / `saves` / `speed` and restore them afterwards; write reports
into `user://test_bug_reports_t0024` and delete it after each test.
- [ ] After `Session._after_load()` on a `from_rows` sim, submitting a `WalkToCommand` and a
  `SetMoveIntentCommand` between several `Session._process(0.25)` calls, then
  `write_bug_report(null, <test dir>)`: the folder has start.json, commands.json, end.json
  and info.txt (no screenshot.png), and `Replay.check()` on the parsed files returns "".
- [ ] After an autosave (drive `_process` across 03:00 as in T-0014's test), the report's
  start is the autosave state, `commands.json` holds only commands applied after it, and the
  replay still returns "".
- [ ] Two reports in the same second get different folders.
- [ ] `info.txt` contains the in-game time and the player's name.
- [ ] The tool reads what the game writes: `ReplayFiles.check_folder(<report folder>,
  content())["status"]` is "OK" for the report of the first criterion.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- `Session`: `_replay_start` (set in `_after_load()` right after the log is cleared, and
  again by `autosave()`, which also clears `command_log`; `_process()` already appends the
  applied commands before its autosave check), `write_bug_report(screenshot, base_dir)`
  (folder named by the real date and time, `_2`, `_3`... on a clash; start.json,
  commands.json, end.json, screenshot.png, info.txt; returns the absolute path).
- F9 (`bug_report`) in `main.gd` grabs the screen, writes the report, prints the path and
  shows "Bug report saved: <folder name>". Works with the Esc menu open too. Hints gain
  "F9 report a bug".
- Tests: `tests/game/test_bug_report.gd` (4): a report replays exactly (also through
  `ReplayFiles.check_folder`), an autosave moves the start and empties the log (two
  mutations, not moving the start or not clearing the log, each fail it), same-second
  reports get their own folders, info.txt has the game time and the player's name.
  `tools/check.sh`: 257 passed, 0 failed.
- Docs: `docs/workflow.md` says where reports go
  (`~/Library/Application Support/Godot/app_userdata/Last Tram/bug_reports/`) and adds F9 to
  the keys.

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
