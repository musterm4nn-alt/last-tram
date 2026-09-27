---
id: T-0014
title: Save slots, daily autosave, and Continue loads the newest save
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0020]
builder:
review_rounds: 0
---

## Goal
The game keeps three manual save slots and two rotating autosaves (written every game day
at 03:00), next to the existing quicksave. The main menu's **Continue** loads the newest save
of any kind. This ticket is the logic and the file handling; the Esc menu that saves into
slots and lists them is T-0023.

## Read first
- `game/session.gd` (saving, loading, `_process`, `_after_load`), `game/ui/main_menu.gd`
  (T-0020 as merged: Continue loads `Session.QUICKSAVE_PATH` and is disabled when missing)
- `sim/core/sim_clock.gd` (`day()`, `minute_of_day()`, `format()`), `sim/save/save_codec.gd`
  (a save is JSON with `"clock": {"tick": N}` at the top level)
- `tests/game/test_objects_view_2d.gd` (how game tests swap `Session` state and restore it)

## Scope
Create `game/save_slots.gd` (`SaveSlots`) and `tests/game/test_save_slots.gd`.
Change `game/session.gd`, `game/ui/main_menu.gd`.
**Out of scope:** the Esc menu, choosing a slot, and a Load list (T-0023); cloud saves;
deleting saves.

## Specification

### `SaveSlots` (`extends RefCounted`; all file names inside one folder)
```gdscript
const SLOT_COUNT: int = 3
const AUTOSAVE_COUNT: int = 2
## Autosaves happen once per game day, at this hour.
const AUTOSAVE_HOUR: int = 3

## The folder holding every save, e.g. "user://saves" (tests use their own folder).
var dir: String

func _init(p_dir: String) -> void
## <dir>/quicksave.json
func quicksave_path() -> String
## <dir>/slot_1.json .. slot_3.json (index 1..SLOT_COUNT)
func slot_path(index: int) -> String
## <dir>/autosave_1.json, autosave_2.json (index 1..AUTOSAVE_COUNT)
func autosave_path(index: int) -> String
## Quicksave, then slots 1-3, then autosaves 1-2 (whether or not the files exist).
func all_paths() -> Array[String]
## The existing file among all_paths() written most recently
## (FileAccess.get_modified_time; ties: the earlier one in all_paths()), or "" if none exist.
func newest_save() -> String
## Where the next autosave goes: the first autosave path that does not exist yet,
## otherwise the one written longest ago.
func next_autosave_path() -> String

## "Day 3  Wed 14:05" from the save's clock (Day is clock.day() + 1, like the HUD), or ""
## if the file is missing or is not a save.
static func describe_game_time(path: String) -> String
## The local real time the file was last written, "2026-09-27 21:14", or "" if missing.
static func describe_real_time(path: String) -> String
## True when a clock at `tick` is at or past AUTOSAVE_HOUR on a day after `last_autosave_day`.
static func autosave_due(tick: int, last_autosave_day: int) -> bool
## The day number an autosave counts as already done for, for a game loaded at `tick`:
## today if it is already past AUTOSAVE_HOUR, else yesterday (so loading at 08:00 does not
## autosave at once, and loading at 02:00 autosaves at 03:00).
static func last_autosave_day_at(tick: int) -> int
```
`describe_game_time` reads only the clock: parse the JSON, take `clock.tick`, and build a
`SimClock` with that tick for `format()`; it never loads the whole Sim. Real time:
`Time.get_datetime_string_from_unix_time(FileAccess.get_modified_time(path) + bias, true)`
cut to 16 characters, where `bias` is `Time.get_time_zone_from_system()["bias"] * 60`
(local time).

### Session
- `var saves: SaveSlots = SaveSlots.new(SAVE_DIR)`; `QUICKSAVE_PATH` stays as it is (it
  equals `saves.quicksave_path()`).
- `var _last_autosave_day: int = -1`; `_after_load()` sets it to
  `SaveSlots.last_autosave_day_at(sim.clock.tick)`.
- In `_process`, after the stepping loop (only when steps ran):
  `if SaveSlots.autosave_due(sim.clock.tick, _last_autosave_day): autosave()`.
- `func autosave() -> void`: `save_to(saves.next_autosave_path())`, then
  `_last_autosave_day = sim.clock.day()`, then `notice.emit("Autosaved")` (or
  `"Autosave failed"`).

### Main menu
- Continue loads `Session.saves.newest_save()` and is disabled when that is `""`.
- Under the Continue button, a small grey label shows the newest save's
  `describe_game_time()` and `describe_real_time()` (hidden when there is none).

## Acceptance criteria (`tests/game/test_save_slots.gd`)
Tests must never touch the real `user://saves`: every test uses
`SaveSlots.new("user://test_saves_t0014")`, clears that folder in `before_each()`, and
deletes it in `after_each()` (`DirAccess.remove_absolute` on each file, then the folder).
Swap `Session.saves` / `Session.sim` / `Session.content` and restore them afterwards.
- [ ] Paths: `slot_path(2)` ends with `/slot_2.json`, `all_paths()` has 6 entries in the
  documented order.
- [ ] `newest_save()`: "" in an empty folder; with two files written, the one modified later
  wins. (Modification times have 1-second resolution: write the second file after
  `OS.delay_msec(1100)`, or set up the case so ties are resolved by order.)
- [ ] `next_autosave_path()`: autosave 1 when none exist, then 2, then (both exist) the older
  of the two.
- [ ] `autosave_due` and `last_autosave_day_at`: day 0 08:00 → last day 0, not due until
  day 1 03:00; day 1 02:00 → last day 0, due at day 1 03:00 and not at 02:59.
- [ ] `describe_game_time` of a real save (write `SaveCodec.to_json` of a sim advanced to
  day 2 14:05) is "Day 3  Wed 14:05"; a missing file and a non-save file give "".
- [ ] Session autosave: with `Session.sim` at day 0 02:59 (build with
  `SimFactory.from_rows` and set the clock tick; call `Session._after_load()` or set
  `_last_autosave_day` the same way) and `Session.saves` on the test folder, running
  `Session._process(...)` for one game minute writes `autosave_1.json`; another minute does
  not write a second autosave.
- [ ] Main menu: build `MainMenu` outside the tree like `test_name_screen.gd`; with no saves
  in the (test) folder Continue is disabled, with one save it is enabled.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
