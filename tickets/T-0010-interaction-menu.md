---
id: T-0010
title: Interaction menu: click an object (command mode) or press E (direct mode)
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0007, T-0009]
builder:
review_rounds: 0
---

## Goal
You can use things. In command mode a left click on an object opens a small menu of what it
offers ("Grab a snack", "Cook a meal"...); in direct mode `E` opens the same menu for the
nearest object in front of you. Choosing an entry queues it, and the character walks there
and does it (T-0007). If it can't happen, a short notice says why. The queue panel with
progress and cancel buttons is T-0028.

## Read first
- `docs/design/controls-and-ui.md` → "Keys", "Interaction menu"
- As merged: `sim/actions/interactions.gd` (`Interactions.offered_by(sim, object_id)` →
  `Array[InteractionDef]` in content order), `sim/commands/queue_interaction_command.gd`,
  the `action_failed` event (`{"person_id", "interaction_id", "reason"}`; reasons
  `"no_free_slot"`, `"no_path"`, `"unknown_interaction"`), `World.objects_at(cell)`,
  `ContentDB.object_def(id)` (`.name`)
- T-0009 (as merged): `Session.command_mode`, `ViewConfig.cell_at(world_px)`,
  `PlayerController.camera` / `walk_command()`, `Hud.hint_text()`, `Hud.notice_for_event()`,
  and the `--command` launch option

## Scope
Create `game/ui/interaction_menu.gd` (`InteractionMenu`) and
`tests/game/test_interaction_menu.gd`. Change `game/input/input_actions.gd`,
`game/input/player_controller.gd`, `game/ui/hud.gd`, `game/main.gd`,
`game/launch_options.gd`, `tests/game/test_launch_options.gd`, `tests/game/test_command_mode.gd`
(only if a hint-text assertion changes).
**Out of scope:** the queue panel and cancelling (T-0028), greying out unavailable options,
clicking people, anything in `sim/`.

## Specification

### Input
`InputActions.KEYS`: `"interact": [KEY_E]`.

### `InteractionMenu` (`extends PopupMenu`)
```gdscript
## Fills the menu for this object (no popup; tests call this): a header with the object's
## name (add_separator(name)), then one item per offered interaction (item id = its index
## in offered_by()), or one disabled item "Nothing to do here".
func prepare(object_id: int) -> void
## prepare(), then popup at `screen_pos` (Rect2i(Vector2i(screen_pos), Vector2i.ZERO)).
func open_for(object_id: int, screen_pos: Vector2) -> void
## The labels prepare() shows, header first (pure, for tests). [] for an unknown object.
static func entries(sim: Sim, object_id: int) -> Array[String]
```
On `id_pressed(id)`: `Session.submit(QueueInteractionCommand.new(player.id, <offered[id].id>,
object_id))`. The menu closes itself on a choice, on Esc and on a click outside (PopupMenu
does this).

### PlayerController
- New `var menu: InteractionMenu` (set by `main.gd`, like `camera`).
- `_process`: while `menu.visible`, the WASD direction is `Vector2.ZERO` (no walking while
  choosing).
- Command mode, `walk_click`: the clicked cell is `ViewConfig.cell_at(camera.get_global_mouse_position())`
  on the player's level. If `Session.sim.world.objects_at(cell)` is not empty, open the menu
  for the first object at the mouse (`get_viewport().get_mouse_position()`); otherwise walk
  there as in T-0009.
- Direct mode, `interact` (E): `nearest_object(Session.sim, player)`; if it is > 0, open the
  menu at the player's screen position
  (`get_viewport().get_canvas_transform() * (player.pos * ViewConfig.TILE_PX)`), else show
  the notice "Nothing to use here" (`Session.notice.emit(...)`).
- ```gdscript
  ## Reach and preference for E: objects with a footprint cell centre within INTERACT_RANGE
  ## of the person count; distance is to the nearest such centre, minus FACING_BONUS when
  ## the direction to it is in front (facing.dot(direction.normalized()) > 0.5).
  const INTERACT_RANGE: float = 1.5
  const FACING_BONUS: float = 0.5
  ## The object E would use, or 0 if none is in reach. Ties: the lower object id.
  static func nearest_object(sim: Sim, person: Person) -> int
  ```

### Hud
- `hint_text(false)` gains `"E use"` after `"WASD move"`; `hint_text(true)` starts with
  `"Click an object to use it, the ground to walk"`.
- `notice_for_event` also turns the player's `action_failed` into
  `"<Interaction name>: <reason words>"`, with reason words `"someone is using it"`
  (`no_free_slot`) and `"can't get there"` (`no_path`), e.g.
  `"Grab a snack: can't get there"`. Other reasons give `""`.

### Launch option (for screenshots)
`--interact=<def_id>`: after the quick start, open the interaction menu for the first object
with that def id, at that object's screen position.

## Acceptance criteria (`tests/game/test_interaction_menu.gd` unless named)
Build sims with `SimFactory.from_rows` and `world.add_object()`, set `Session.sim` /
`Session.content`, and restore them afterwards.
- [ ] `InteractionMenu.entries`: a fridge gives `["Fridge", "Grab a snack"]`; a double bed
  lists "Double bed" then its interactions in content order; an unknown id gives `[]`.
- [ ] Choosing: after `prepare(fridge_id)` on a menu outside the tree, emitting
  `id_pressed(0)` leaves one pending `QueueInteractionCommand` in `Session.sim` for the
  player, `"grab_snack"` and the fridge id.
- [ ] `nearest_object`: an object 1 cell in front beats one 1 cell behind; one 1 cell to the
  side beats one 1.4 cells away; nothing within 1.5 cells gives 0.
- [ ] `Hud.notice_for_event`: the player's `action_failed` with `no_path` →
  `"Grab a snack: can't get there"`; another person's → `""`.
- [ ] `test_launch_options.gd`: `--interact=fridge` parses and skips the menu.
- [ ] Screenshot: `tools/screenshot.sh out/t0010_menu.png --interact=fridge` shows
  the menu with the header "Fridge" and the item "Grab a snack" next to the fridge. Open the
  PNG and look at it. (Walking there and eating is already proven by T-0007's sim tests.)
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
