---
id: T-0049
title: Floors in the view - Page Up/Down, keyboard stairs, clicking on other floors
status: done
milestone: M2
size: M
owner: builder
depends_on: [T-0030]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
Make floors playable before the town gets them (T-0031). In direct mode, Page Up / Page Down
on a stairs cell climbs up or down. In command mode they page the view through the floors,
and clicking walks to the floor you're looking at. The view follows you whenever your floor
changes; `--level=N` shows a floor for screenshots.

## Read first
- `docs/design/controls-and-ui.md` → "Keys" (Page Up/Down), "Camera"
- As merged: `sim/world/pathfinder.gd` (stair links, `_is_linked_pair`), `game/session.gd`
  (`viewed_level`, set after stepping since T-0030), `game/input/player_controller.gd`
  (`walk_command`, `_unhandled_input`), `game/ui/hud.gd` (mode label, hints),
  `game/launch_options.gd`, `game/main.gd` (`_start_quick`)

## Scope
Change `sim/world/pathfinder.gd`, `game/session.gd`, `game/input/input_actions.gd`,
`game/input/player_controller.gd`, `game/ui/hud.gd`, `game/launch_options.gd`,
`game/main.gd`, `docs/design/controls-and-ui.md` (Page Up/Down row → M2, built).
Create `tests/game/test_floor_view.gd`.
**Out of scope:** town floors (T-0031), roof cut-away, seeing the floor below through gaps.

## Specification
- `Pathfinder.is_stair_link(a: Vector3i, b: Vector3i) -> bool`: the renamed, now public
  `_is_linked_pair` (all callers updated).
- `Session`:
  - `viewed_level` follows the player: after stepping, it changes only when the player's
    level differs from the level it last followed (`_followed_level`), so a paged view
    stays put while the player stays on one floor. Loading or a new game resets both to
    the player's level. Switching to direct mode (`set_command_mode(false)`) snaps
    `viewed_level` back to the player's level.
  - `func view_level(level: int) -> void`: sets `viewed_level` if the grid has that level.
  - `func page_level(delta: int) -> void`: moves `viewed_level` to the next existing level
    above (+1) or below (−1), skipping missing levels; does nothing at the top or bottom.
- Input actions `"level_up": [KEY_PAGEUP]`, `"level_down": [KEY_PAGEDOWN]`.
- `PlayerController`:
  - `static func stairs_command(sim: Sim, player: Person, delta: int) -> WalkToCommand`:
    a WalkTo to the cell straight above (`delta` 1) or below (−1) when the player stands on
    a stairs cell linked to it (`sim.nav.is_stair_link`), else null.
  - `_unhandled_input`: `level_up`/`level_down` in command mode → `Session.page_level(±1)`.
    In direct mode → submit `stairs_command`, or `Session.notice.emit("No stairs here")`.
  - `walk_command(player, world_px, level)`: the clicked cell on `level`. The click handler
    passes `Session.viewed_level`, and looks up objects on that level too.
- HUD: in command mode, when `viewed_level` differs from the player's level, the mode label
  reads "Command mode · floor N" (N = viewed level). Hints: direct mode adds
  "PgUp/PgDn stairs", command mode adds "PgUp/PgDn floors". Drop "F3 debug" from the direct
  hints if the line no longer fits 1280 px (F3 still works).
- `--level=N`: after the quick start, `Session.view_level(N)` (documented in main.gd and
  LaunchOptions).

## Acceptance criteria (`tests/game/test_floor_view.gd`)
Two- or three-level worlds: `SimFactory.from_rows` + `grid.stamp_rows(level, ...)`.
- [x] `page_level` walks through existing levels (0 → 1 → 2 and back), skips a missing
  level and stops at the ends.
- [x] A paged view stays put while the player stays on one floor; when the player's level
  changes, it follows; direct mode snaps it back.
- [x] Direct mode: Page Up on a linked stairs cell sends a WalkTo to the cell above, and after
  running the sim the player is on level 1; Page Down brings them back. Off the stairs, no
  command and the notice "No stairs here".
- [x] Command mode: a click while viewing level 1 sends a WalkTo whose target has z = 1.
- [x] `tools/check.sh` passes; screenshot `out/t0049.png` (the hint line fits).

## Implementation notes
- `Pathfinder.is_stair_link` (renamed from `_is_linked_pair`).
- `Session`: `_followed_level` + `_follow_player_level()` after stepping (replacing
  T-0030's unconditional follow), reset on load; `view_level`, `page_level`; leaving
  command mode snaps to the player's floor.
- `PlayerController.press_level_key(delta)` holds the Page Up/Down logic (so tests can call
  it without a viewport); `_unhandled_input` routes `level_up`/`level_down` to it.
  `stairs_command`, and `walk_command(player, world_px, level)`; clicks use
  `Session.viewed_level` for walking and for objects.
- HUD: `Hud.mode_text` ("Command mode · floor N"); hints gain PgUp/PgDn, and "F3 debug"
  left the direct-mode line to make room (F3 still works).
- `--level=N` (`LaunchOptions.level`, `NO_LEVEL`).
- `test_command_mode.gd`: the walk-command test now passes the level explicitly and also
  checks another level (the signature changed by spec).
- Verified: `tools/check.sh` 374 passed, 0 failed (`test_floor_view.gd`, 8 tests).
  Screenshots `out/t0049.png` (direct hints) and `out/t0049_command.png` (command hints):
  both lines fit at 1280 px. Floors themselves arrive with T-0031.

## Questions

## Review feedback
