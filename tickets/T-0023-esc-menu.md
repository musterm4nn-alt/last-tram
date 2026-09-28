---
id: T-0023
title: Esc menu (resume, save to a slot, load, quit) and a Load list in the main menu
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0014, T-0010]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
During a game, **Esc** pauses and opens a menu: Resume, Save game (pick one of three slots),
Load game (any existing save: quicksave, slots, autosaves), Quit game. The main menu gets the
same **Load game** list. Each save shows its in-game date and when it was written.

## Read first
- T-0014 as merged: `game/save_slots.gd` (`SaveSlots`: `slot_path(i)`, `autosave_path(i)`,
  `quicksave_path()`, `all_paths()`, `describe_game_time(path)`, `describe_real_time(path)`)
  and `Session.saves`
- `game/session.gd` (`save_to`, `load_from`, `set_speed`, `speed`, `notice`),
  `game/ui/main_menu.gd` (button style: `_button()`), `game/main.gd`, `game/launch_options.gd`
- `tests/game/test_name_screen.gd` (building UI outside the tree in tests)

## Scope
Create `game/ui/save_list.gd` (`SaveList`), `game/ui/pause_menu.gd` (`PauseMenu`),
`tests/game/test_pause_menu.gd`. Change `game/input/input_actions.gd`, `game/main.gd`,
`game/ui/main_menu.gd`, `game/ui/hud.gd` (hint line), `game/input/player_controller.gd`,
`game/launch_options.gd`, `tests/game/test_launch_options.gd`.
**Out of scope:** deleting or renaming saves, overwrite confirmation, a settings screen,
returning to the main menu from a game.

## Specification

### Input
`InputActions.KEYS`: `"menu": [KEY_ESCAPE]`.

### `SaveList` (`extends VBoxContainer`)
```gdscript
## A button was chosen: save into / load from this file.
signal chosen(path: String)
## "Back" was pressed.
signal back_pressed

## Rows to show (pure, for tests). Each row: {"path": String, "label": String}.
## for_save = true: the three slots, always, labelled "Slot 1 · Day 3  Wed 14:05 · 2026-09-27 21:14"
##   or "Slot 1 · empty".
## for_save = false: only files that exist, in all_paths() order, named "Quicksave",
##   "Slot 1".."Slot 3", "Autosave 1", "Autosave 2", with the same " · game time · real time".
static func rows(saves: SaveSlots, for_save: bool) -> Array[Dictionary]
## Rebuilds the buttons from rows() plus a Back button at the end.
func show_rows(saves: SaveSlots, for_save: bool) -> void
```
With `for_save = false` and no saves, the list shows one disabled button "No saves yet"
(plus Back).

### `PauseMenu` (`extends CanvasLayer`, `layer = 15`)
- A dimmed full-screen `ColorRect` (Color(0, 0, 0, 0.6)) with a centred panel, like
  `MainMenu`. Hidden until opened.
- ```gdscript
  var is_open: bool = false
  ## Pauses (remembers Session.speed, then Session.set_speed(0)) and shows the main page.
  func open() -> void
  ## Hides the menu and restores the speed it had before open().
  func close() -> void
  ```
- Main page buttons: **Resume** (`close()`), **Save game** (shows `SaveList` with
  `for_save = true`), **Load game** (`SaveList` with `for_save = false`), **Quit game**
  (`get_tree().quit()`).
- Saving: on `chosen(path)` → `Session.save_to(path)`; notice "Saved to slot N" (or
  "Saving failed"); refresh the list so the new time shows.
- Loading: on `chosen(path)` → `close()` first (restore speed), then `Session.load_from(path)`;
  on failure notice "Could not load that save".
- `main.gd` creates it once (after the HUD) and, in `_unhandled_input`, on `menu`:
  if a game is running (`Session.sim != null`), there is no main menu or name (or creator)
  screen, and the interaction menu (T-0010) is not open, toggle it (`open()` / `close()`). While it is open, the rest of the game ignores input:
  `PlayerController` sends no movement while `pause_menu.is_open` (pass the menu to it, like
  the camera) and `main.gd` ignores speed and save keys.

### Main menu
- A **Load game** button under Continue shows a `SaveList` (`for_save = false`) in place of
  the buttons; Back returns to the buttons; `chosen(path)` → `Session.load_from(path)`.

### Hud
`Hud.hint_text()` gains `"Esc menu"` in both modes.

### Launch options (for screenshots)
- `--screen=pause`: after the quick start, open the pause menu.
- `--screen=load`: open the main menu's Load list (forces the menu, like `--screen=name`).

## Acceptance criteria (`tests/game/test_pause_menu.gd` unless named)
Tests use `SaveSlots.new("user://test_saves_t0023")` (cleared before, deleted after each
test) as `Session.saves`, and restore every `Session` field they change.
- [ ] `SaveList.rows(saves, true)`: three rows, "Slot 1 · empty" when missing, with game and
  real time when the file exists.
- [ ] `SaveList.rows(saves, false)`: only existing files, in `all_paths()` order, with the
  right names; empty when there are no saves.
- [ ] `PauseMenu.open()` pauses (`Session.speed == 0`, `is_open`), `close()` restores the
  previous speed (test with speed 2).
- [ ] Choosing slot 2 in the Save list writes `slot_2.json` in the test folder, and the row
  then shows a game time.
- [ ] Choosing a save in the Load list loads it (`Session.sim.clock.tick` equals the saved
  tick) and closes the menu.
- [ ] `test_launch_options.gd`: `--screen=pause` and `--screen=load` parse.
- [ ] Screenshots: `tools/screenshot.sh out/t0023_pause.png --screen=pause` (the Esc menu over
  the dimmed town) and `tools/screenshot.sh out/t0023_load.png --screen=load` (the main menu's
  Load list). Open both and look at them.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- `game/ui/save_list.gd` (`SaveList`): `rows()` (pure) and `show_rows()`; "No saves yet"
  when there is nothing to load.
- `game/ui/pause_menu.gd` (`PauseMenu`, layer 15): `open()` pauses and remembers the speed,
  `close()` restores it; Resume, Save game (three slots, notice "Saved to slot 2"),
  Load game (closes, then loads; "Could not load that save" on failure), Quit game.
- `main.gd`: Esc toggles it only during a game with no menu screen up and the interaction
  menu closed; while it is open the other keys are ignored, and `PlayerController` sends no
  movement and ignores clicks and E.
- Main menu: a Load game button shows the same list (Back returns).
- Hints gain "Esc menu"; `--screen=pause` and `--screen=load` (the latter, like
  `--screen=name`, now always shows the menu).
- Tests: `tests/game/test_pause_menu.gd` (6, in `user://test_saves_t0023`) and one in
  `test_launch_options.gd`. `tools/check.sh`: 224 passed, 0 failed.
- Screenshots: `out/t0023_pause.png` (the menu over the dimmed town, clock "PAUSED") and
  `out/t0023_load.png` (the main menu's Load list: "No saves yet" and Back, since the
  owner has no saves).
- Docs: the keys line in `docs/workflow.md`.

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
