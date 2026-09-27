---
id: T-0009
title: Command mode: Tab toggle, free camera, click the ground to walk
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0004]
builder:
review_rounds: 0
---

## Goal
`Tab` switches between **direct mode** (WASD walks, the camera follows the player) and
**command mode** (WASD or right-drag pans the camera, and a left click on the ground walks the
player there with `WalkToCommand`). While the player walks to a clicked cell, a small ring
marks the destination. The HUD shows which mode is on.

## Read first
- `docs/design/actions-and-autonomy.md` → "Control modes" (only the Move and Camera rows;
  interacting is T-0010)
- `game/input/player_controller.gd`, `game/view2d/camera_rig_2d.gd`, `game/ui/hud.gd`,
  `game/main.gd`, `game/session.gd`, `game/launch_options.gd`
- `sim/commands/walk_to_command.gd` (T-0004, merged): `WalkToCommand.new(person_id, cell)`
  sets `person.path` (the cells still to walk, ending at the target), or emits
  `&"path_failed"` `{"person_id", "target"}` if the cell can't be reached. A **zero**
  `SetMoveIntentCommand` leaves the path alone; a non-zero one clears it.
- `tests/game/test_objects_view_2d.gd` (how game tests swap `Session.sim` and restore it)

## Scope
Create `game/view2d/path_marker_2d.gd` (`PathMarker2D`) and `tests/game/test_command_mode.gd`.
Change `game/session.gd`, `game/input/input_actions.gd`, `game/input/player_controller.gd`,
`game/view2d/camera_rig_2d.gd`, `game/view2d/view_config.gd`, `game/ui/hud.gd`,
`game/main.gd`, `game/launch_options.gd`, `tests/game/test_launch_options.gd`.
**Out of scope:** clicking objects or people, the interaction menu and `E` (T-0010); level
paging; anything in `sim/`.

## Specification

### Session (view state, like `speed` and `viewed_level`; never saved)
```gdscript
## Emitted when Tab switches between direct and command mode.
signal command_mode_changed(on: bool)
## True in command mode (camera pans freely, click the ground to walk).
var command_mode: bool = false
## Switches the mode; emits command_mode_changed only when it actually changes.
func set_command_mode(on: bool) -> void
```
`_after_load()` calls `set_command_mode(false)` before `game_loaded.emit()` (every new or
loaded game starts in direct mode).

### Input (`InputActions`)
- `KEYS`: `"toggle_command_mode": [KEY_TAB]`.
- `MOUSE_BUTTONS`: `"walk_click": [MOUSE_BUTTON_LEFT]`, `"pan_drag": [MOUSE_BUTTON_RIGHT]`.
- `main.gd` `_unhandled_input`: `toggle_command_mode` → `Session.set_command_mode(not
  Session.command_mode)`.

### ViewConfig
```gdscript
## Screen pixels per second the camera pans in command mode (divided by the zoom).
const PAN_SPEED_PX: float = 600.0
## The cell under a world-space pixel position (floor, so it works left of / above 0 too).
static func cell_at(world_px: Vector2) -> Vector2i
```

### PlayerController
- New `var camera: CameraRig2D` (set by `main.gd` before `add_child`).
- `_process`: in command mode the WASD direction is `Vector2.ZERO` (WASD pans the camera
  instead); `forced_direction` (`--walk`) only applies in direct mode. The existing
  "send only when it changes" logic then sends one zero intent when you press Tab while
  walking: the player stops, but a path they are following keeps going.
- `_unhandled_input(event)`: in command mode, on `event.is_action_pressed("walk_click")`:
  `Session.submit(walk_command(player, camera.get_global_mouse_position()))`, then
  `get_viewport().set_input_as_handled()`. Do nothing if there is no sim or no player.
- ```gdscript
  ## The WalkToCommand for a click at `world_px`: the clicked cell on the player's level.
  static func walk_command(player: Person, world_px: Vector2) -> WalkToCommand
  ```

### CameraRig2D
- Direct mode: follow the player exactly as today.
- Command mode: stop following. Each frame, pan by
  `Input.get_vector("move_left", "move_right", "move_up", "move_down") * ViewConfig.PAN_SPEED_PX * delta / zoom.x`.
  While `pan_drag` is held, `InputEventMouseMotion` pans by `-event.relative / zoom.x`
  (drag the town under the mouse). Keep `position` inside the town
  (`clamp_to_town(position, grid)`).
- On `Session.command_mode_changed(false)`: jump back to the player (`_follow()` then
  `reset_smoothing()`).
- ```gdscript
  ## `pos` clamped to the town in pixels: x in 0..grid.width*TILE_PX, y in 0..grid.height*TILE_PX.
  static func clamp_to_town(pos: Vector2, grid: WorldGrid) -> Vector2
  ## One frame of keyboard panning (pure, for tests).
  static func pan_step(pos: Vector2, direction: Vector2, delta: float, zoom: float) -> Vector2
  ```

### PathMarker2D (new, `extends Node2D`)
- Added in `main.gd` right **before** `PeopleView2D` (so people draw on top).
- Each frame (`queue_redraw()` in `_process`): if the player has a non-empty `path` and the
  last cell is on `Session.viewed_level`, draw a ring (`draw_arc`, radius 0.35 cell, width
  2 px, colour `ViewConfig.PLAYER_MARKER_COLOR`) at that cell's centre. Otherwise draw nothing.
- ```gdscript
  ## Centre (pixels) of the player's destination, or null when there is none to show.
  static func marker_centre(person: Person, level: int) -> Variant
  ```
  (returns a `Vector2`, or `null` when the path is empty or ends on another level).

### Hud
- The hint line comes from `static func hint_text(command_mode: bool) -> String`:
  - direct: `"WASD move   Tab command mode   Space pause   1-3 speed   Wheel zoom   F5 save   F8 load   F3 debug"`
  - command: `"Click walk there   WASD / right-drag pan   Tab direct mode   Space pause   1-3 speed   Wheel zoom"`
  Update it on `Session.command_mode_changed`.
- Under the place label in the top panel, a mode label: `"Command mode"` in command mode,
  hidden in direct mode.
- "Can't get there": connect `Session.sim_event`; for each event,
  `static func notice_for_event(event: Dictionary, player_id: int) -> String` returns
  `"Can't get there"` for `&"path_failed"` of the player (else `""`), and a non-empty result
  is shown with the existing `_show_notice()`.

### Launch options (for screenshots)
- `--command` → `command_mode = true`: `main.gd` calls `Session.set_command_mode(true)` after
  the quick start.
- `--walk-to=X,Y` → `walk_to: Vector2i` (default `Vector2i(-1, -1)` = none; reuse
  `_parse_walk` and convert): after the quick start, `main.gd` submits
  `WalkToCommand.new(player.id, Vector3i(X, Y, player.level))`. Both options also count for
  `skip_menu()`.

## Acceptance criteria (`tests/game/test_command_mode.gd` unless named)
- [ ] `Session.set_command_mode` flips the flag and emits `command_mode_changed` once per
  real change (setting the same value twice emits once); `_after_load()` resets it to direct
  (test: set it on, call `Session.new_game(1)`, check it is off; restore `Session.sim` and
  `Session.content` afterwards).
- [ ] `ViewConfig.cell_at`: (0,0) → (0,0); (15.9,15.9) → (0,0); (16,32) → (1,2);
  (-0.1,-0.1) → (-1,-1).
- [ ] `PlayerController.walk_command`: a player on level 0, a click at pixel (37, 20) gives a
  `WalkToCommand` for the player's id and cell (2, 1, 0).
- [ ] Clicking walks: with `Session.sim = SimFactory.from_rows(content(), ROOM)`, submit the
  command from `walk_command`, step the sim (tests may step) until the path is empty, and
  the player stands on the clicked cell.
- [ ] `CameraRig2D.pan_step` moves by `PAN_SPEED_PX * delta / zoom` in the direction;
  `clamp_to_town` keeps a position inside the town (both corners and a point outside).
- [ ] `PathMarker2D.marker_centre`: null with an empty path; the centre pixel of the last
  cell with a path; null when the last cell is on another level.
- [ ] `Hud.hint_text` differs by mode and mentions Tab in both; `Hud.notice_for_event` gives
  "Can't get there" only for the player's own `path_failed`.
- [ ] `tests/game/test_launch_options.gd`: `--command` and `--walk-to=40,22` parse, and each
  makes `skip_menu()` true.
- [ ] Screenshot: `tools/screenshot.sh out/t0009.png --command --walk-to=40,22 --frames=40`
  shows the command-mode hint line, the "Command mode" label, and the ring at (40, 22) with the
  player on the way. Open the PNG and look at it.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
