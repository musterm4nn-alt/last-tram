---
id: T-0028
title: Action queue panel (progress and cancel) and rising-need arrows
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0010]
builder:
review_rounds: 0
---

## Goal
At the bottom centre of the screen, a panel shows what the character is doing and what is
queued: the current action with a progress bar, then up to five more, each with a × button
that cancels it. Needs that the current action is filling show a small ▲ in the needs panel.

## Read first
- `docs/design/controls-and-ui.md` → "HUD layout", "Action queue", "Needs panel"
- As merged: `sim/actions/action.gd` (`Action`: `interaction_id`, `state` QUEUED / ROUTING /
  PERFORMING, `minutes_done`), `Person.action_queue` (front = current, `Person.MAX_QUEUE`
  = 6), `sim/content/interaction_def.gd` (`duration_minutes`, `until_need`, `need_rates`),
  `NeedDef.decay_per_hour`, `sim/commands/cancel_action_command.gd`
  (`CancelActionCommand.new(person_id, index)`)
- `game/ui/needs_panel.gd` and `game/ui/hud.gd` (panel style, how the HUD places panels)

## Scope
Create `game/ui/action_queue_panel.gd` (`ActionQueuePanel`) and
`tests/game/test_action_queue_panel.gd`. Change `game/ui/hud.gd` (add the panel),
`game/ui/needs_panel.gd` (arrows), `tests/game/test_needs_panel.gd` (add arrow tests),
`game/launch_options.gd`, `game/main.gd`, `tests/game/test_launch_options.gd`.
**Out of scope:** reordering the queue, moodlets, anything in `sim/`.

## Specification

### `ActionQueuePanel` (`extends PanelContainer`, the same dark style as `NeedsPanel`)
- Anchored bottom centre (`anchor_left = anchor_right = 0.5`, `anchor_top = anchor_bottom = 1`,
  grow both ways horizontally, up vertically), 12 px above the bottom edge. Hidden when the
  player's queue is empty.
- One row per action in the player's queue: a label (`row_text`), for the front action a
  `ProgressBar` (0..1, 160×8 px) showing `progress()`, and a small "×" `Button` that submits
  `CancelActionCommand.new(player.id, index)`.
- Rebuild the rows only when `signature()` changes; otherwise just update the front bar's
  value each frame.
- ```gdscript
  ## "Grab a snack · walking there" (front, QUEUED or ROUTING), "Grab a snack" (front,
  ## PERFORMING), "Then: Watch TV" (every other row). Unknown interaction ids show the id.
  static func row_text(action: Action, index: int, content: ContentDB) -> String
  ## 0..1 for the front action: minutes_done / duration_minutes for fixed-length ones; the
  ## need's value / 100 for until_need ones (e.g. energy while sleeping); 0 unless PERFORMING.
  static func progress(action: Action, person: Person, content: ContentDB) -> float
  ## Changes whenever rows must be rebuilt: "<id>:<state>" for each action, joined by "|".
  static func signature(person: Person) -> String
  ```

### Needs panel arrows
- ```gdscript
  ## True when the person's front action is PERFORMING and adds more of this need per hour
  ## than the need decays (need_rates[need_id] > decay_per_hour).
  static func is_rising(person: Person, need_id: String, content: ContentDB) -> bool
  ```
- Each row gets a small label after the bar: "▲" (colour `GOOD_COLOR`) when rising, empty
  otherwise. Updated in `show_person()`.

### Launch option (for screenshots)
`--queue=<def_id>:<interaction_id>,...` (e.g. `--queue=fridge:grab_snack,tv:watch_tv`):
right after the new game starts and **before** `--advance` runs, submit a
`QueueInteractionCommand` for each pair, on the first object with that def id, in order.

## Acceptance criteria
- [ ] `test_action_queue_panel.gd`: `row_text` for a front ROUTING, a front PERFORMING and a
  second action; `progress` for grab_snack at 2 of 5 minutes (0.4), for sleep with energy 55
  (0.55), and 0 while ROUTING; `signature` changes when an action is added or its state
  changes, and not when only `minutes_done` changes.
- [ ] Cancel: build the panel outside the tree for a player with two queued actions, press
  the second row's × (`button.pressed.emit()`), and `Session.sim` has a pending
  `CancelActionCommand` with index 1. Restore `Session` afterwards.
- [ ] `test_needs_panel.gd`: `is_rising` is true for fun while watching TV (25 > 6), false for
  comfort while watching TV (−2), false when the action is only ROUTING, false with an empty
  queue.
- [ ] `test_launch_options.gd`: `--queue=fridge:grab_snack,tv:watch_tv` parses into two pairs
  and skips the menu.
- [ ] Screenshot: `tools/screenshot.sh out/t0028.png --queue=fridge:grab_snack,tv:watch_tv --advance=4`
  shows the panel at the bottom centre: "Grab a snack" with a partly filled bar and
  "Then: Watch TV", each with ×. Open the PNG and look at it.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
