---
id: T-0008
title: Needs panel in the HUD
status: done
milestone: M1
size: S
owner: builder
depends_on: []
builder: OpenCode / DeepSeek V4.1 Flash
review_rounds: 0
---

## Goal
The player sees their six needs as coloured bars with a mood label, bottom-left of the
screen, above the key hints. (The current action and queue come with T-0010's action panel;
trend arrows come once needs can go up, after T-0006.)

## Read first
- `AGENTS.md`, `docs/conventions.md`
- `docs/design/controls-and-ui.md` → the HUD sketch and "Needs panel"
- `game/ui/hud.gd` (how HUD panels are built in code), `game/ui/name_screen.gd` and
  `tests/game/test_name_screen.gd` (how a UI class is tested headless)
- `sim/people/mood.gd` (`Mood.compute`, `Mood.label`), `sim/content/need_def.gd`

## Scope
Create `game/ui/needs_panel.gd`, `tests/game/test_needs_panel.gd`.
Change `game/ui/hud.gd` (add the panel).
**Out of scope:** anything in `sim/`; the current action or queue (T-0010); trend arrows;
hovering for moodlets (M2).

## Specification

### `NeedsPanel` (`game/ui/needs_panel.gd`)
```gdscript
class_name NeedsPanel
extends PanelContainer
## HUD panel: one bar per need (data/needs.json order) and the mood label. Reads the
## player's needs from Session every frame; never writes sim state.

const GOOD_COLOR: Color = Color("#6fae5a")      # value >= 60
const OK_COLOR: Color = Color("#d6b545")        # 30 <= value < 60
const LOW_COLOR: Color = Color("#c8553d")       # value < 30
const BAR_BACKGROUND: Color = Color(1, 1, 1, 0.12)
const BAR_SIZE: Vector2 = Vector2(120, 10)

var _bars: Dictionary[String, ProgressBar] = {}   # need id -> bar, in data order
var _fills: Dictionary[String, StyleBoxFlat] = {} # need id -> the bar's fill style
var _mood_label: Label

## Bar colour for a need value 0..100.
static func bar_color(value: float) -> Color

func _ready() -> void                  # build(Session.content)

## Builds one row per need (call once). Tests call this directly with test content.
func build(content: ContentDB) -> void

## Shows `person`'s needs and mood.
func show_person(person: Person, content: ContentDB) -> void

func _process(_delta: float) -> void   # if Session.sim != null and the player exists: show_person(player, Session.content)
```
- Panel style: the same `StyleBoxFlat` as `Hud._panel()` (bg `Color(0.07, 0.07, 0.09, 0.78)`,
  corner radius 6, content margin 8), set with `add_theme_stylebox_override("panel", ...)`.
- `build()`: a `VBoxContainer` (separation 4). For each `NeedDef` in `content.needs`: an
  `HBoxContainer` with a `Label` (`need_def.name`, font size 13, minimum width 74) and a
  `ProgressBar` (`min_value` 0, `max_value` 100, `show_percentage` false,
  `custom_minimum_size` = `BAR_SIZE`, `size_flags_vertical` = `SIZE_SHRINK_CENTER`). Give each
  bar its own `StyleBoxFlat` for `"fill"` (stored in `_fills`) and one with `BAR_BACKGROUND`
  for `"background"`. Last row: `_mood_label` (font size 14).
- `show_person()`: for each need, `value = float(person.needs.get(id, need_def.start))`;
  set the bar's `value` and its fill's `bg_color = bar_color(value)`. Then
  `_mood_label.text = "Mood: %s" % Mood.label(Mood.compute(person, content))`.

### `Hud` (`game/ui/hud.gd`)
In `_ready()`, after the key-hints panel, add the panel above it:
```gdscript
var needs_panel := NeedsPanel.new()
needs_panel.anchor_top = 1.0
needs_panel.anchor_bottom = 1.0
needs_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
needs_panel.offset_left = 12
needs_panel.offset_top = -56
needs_panel.offset_bottom = -56
add_child(needs_panel)
```
(The HUD is hidden until a game loads, so the panel is too.)

## Acceptance criteria
`tests/game/test_needs_panel.gd` (create panels with `NeedsPanel.new()` and call
`build(content())` directly; don't add them to the tree; read `_bars`, `_fills` and
`_mood_label` directly, like `test_name_screen.gd` does; `free()` the panel at the end):
- [ ] `test_one_bar_per_need_in_data_order`: `_bars.keys()` equals the ids of
  `content().needs`, in order (6 bars).
- [ ] `test_bars_show_values_and_colours`: a `Person.new()` with every need at 80, then hunger
  12 and energy 55: after `show_person`, hunger's bar value is 12 and its fill is
  `LOW_COLOR`, energy's is 55 and `OK_COLOR`, fun's is 80 and `GOOD_COLOR`.
- [ ] `test_mood_label`: all needs 100 → `"Mood: Fine"`; all needs 0 → `"Mood: Miserable"`.
- [ ] `test_bar_color_thresholds`: `bar_color` gives GOOD at 60 and 100, OK at 59.9 and 30,
  LOW at 29.9 and 0.
- [ ] `tools/screenshot.sh out/t0008_start.png` shows the panel bottom-left, above the key
  hints, not overlapping them: six green bars and "Mood: Fine".
- [ ] `tools/screenshot.sh out/t0008_4h.png --advance=240` (4 game hours later): hunger, fun
  and comfort are yellow, energy, hygiene and social are green, and the label says
  "Mood: Okay".
- [ ] `tools/screenshot.sh out/t0008_8h.png --advance=480`: comfort is red, the other five
  are yellow, and the label says "Mood: Uneasy". Open all three PNGs and describe them in
  your notes.
- [ ] `tools/check.sh` passes.

## Implementation notes

- Added `game/ui/needs_panel.gd` (`NeedsPanel extends PanelContainer`): `bar_color()` static
  helper (GOOD >= 60, OK >= 30, LOW below), `_ready()` sets the same `StyleBoxFlat` as
  `Hud._panel()` and calls `build(Session.content)`, `build()` creates one HBox row per
  `NeedDef` (name label, width 74, font 13) plus a `ProgressBar` (0..100, no %, 120×10,
  vertical shrink-centre) with its own fill `StyleBoxFlat` stored in `_fills`, then the mood
  `Label` (font 14). `show_person()` sets each bar value and fill colour, and the label from
  `Mood.label(Mood.compute(...))`. `_process()` reads `Session.sim.world.player()` and
  `Session.content` every frame; it never writes sim state.
- `game/ui/hud.gd`: `_ready()` now adds a `NeedsPanel` anchored bottom-left, offset -56 from
  the bottom so it sits just above the key hints panel (exact snippet from the ticket). The
  HUD is hidden until `game_loaded`, so the panel appears with it.
- Added `tests/game/test_needs_panel.gd` with the four ticket tests. Panels are built with
  `NeedsPanel.new()` + `build(content())` outside the tree and freed at the end, like
  `test_name_screen.gd`.
- Verified: `tools/check.sh` → **107 passed, 0 failed** (incl. the 4 new tests, confirmed
  with `tools/test.sh --filter=needs_panel`: 4 passed).
- Screenshots (opened and checked):
  - `out/t0008_start.png` — panel bottom-left above the hints, no overlap; six green bars
    ("Hunger".."Comfort") and "Mood: Fine".
  - `out/t0008_4h.png` (`--advance=240`, Day 1 12:00) — Hunger, Fun and Comfort yellow;
    Energy, Hygiene and Social green; "Mood: Okay".
  - `out/t0008_8h.png` (`--advance=480`, Day 1 16:00) — Comfort red; the other five yellow;
    "Mood: Uneasy".
- Not in scope (as the ticket says): current action/queue (T-0010), trend arrows, hover
  moodlets (M2).

## Questions

## Review feedback

**Round 1 (architect): passed with no changes.** Built from the latest `main` (the new
"pull first" step worked). Code matches the spec, the four tests check real values and
colours, and the reviewer's own three screenshots match every visual criterion (six green
bars and "Mood: Fine"; the 4-hour mix and "Mood: Okay"; comfort red and "Mood: Uneasy"),
with no overlap with the key hints.
