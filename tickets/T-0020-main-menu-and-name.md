---
id: T-0020
title: Main menu, launch options, and choosing your name
status: todo
milestone: M1
size: M
owner: builder
depends_on: [T-0019]
builder:
review_rounds: 0
---

## Goal
Starting the game shows a **main menu** (New game, Continue, Quit). **New game** asks for
your character's first name, last name and optional nickname, then starts the game with that
name. Tools and tests keep starting straight into the game.

## Read first
- `docs/design/controls-and-ui.md` → "Main menu and character creator (M1)"
- `docs/design/character-and-appearance.md` → "The character creator"
- Code: `game/main.gd` (current option parsing and startup), `game/ui/hud.gd` (UI built in
  code), `game/session.gd`, T-0018's `CharacterSpec`

## Scope
Create `game/launch_options.gd`, `game/ui/main_menu.gd`, `game/ui/name_screen.gd`,
`tests/game/test_launch_options.gd`.
Change `game/main.gd` (use LaunchOptions; menu flow; show and hide the game).
**Out of scope:** the full appearance creator (T-0021), save slots and Load (T-0014), the Esc
menu, anything in `sim/`.

## Specification
- `LaunchOptions` (RefCounted):
  ```gdscript
  var seed_value: int = 1
  var seed_given: bool = false
  var load_path: String = ""
  var advance_minutes: int = 0
  var walk: Vector2 = Vector2.ZERO
  var debug: bool = false
  var zoom: int = -1                  # -1 = default
  var screenshot_path: String = ""
  var screenshot_frames: int = 20
  var random_character: bool = false
  var quickstart: bool = false
  var menu: bool = false              # force the menu (e.g. to screenshot it)
  var screen: String = ""             # "" or "name": open the name screen directly
  static func parse(args: PackedStringArray) -> LaunchOptions   # "--seed=5 --debug" style, as today
  ## True when the game should start immediately, without the menu.
  func skip_menu() -> bool
  ```
  `skip_menu()`: false if `menu`; otherwise true if any of quickstart, screenshot_path,
  load_path, advance_minutes > 0, walk, random_character or seed_given is set; else false.
  Support every option `game/main.gd` supports today, plus `--quickstart`, `--menu`,
  `--screen=name`.
- `main.gd`: parse once. If `skip_menu()` → today's behaviour (load, or new game with the
  default or random character). Else show `MainMenu`. The HUD and debug overlay are hidden
  until `Session.game_loaded`. Keep the doc comment listing all options up to date.
- `MainMenu` (CanvasLayer, built in code): a full-screen dark background, the title
  **LAST TRAM**, the subtitle *"Miss the last tram and the night decides what happens next."*,
  and buttons **New game** (opens `NameScreen`), **Continue** (loads `Session.QUICKSAVE_PATH`;
  disabled when that file doesn't exist) and **Quit**. It closes itself when a game loads.
- `NameScreen` (CanvasLayer, built in code): fields First name, Last name, Nickname
  (optional). The fields start **empty**: the player names their character (the default
  player's name is only for tools, tests and quick starts, never pre-filled here). a **Random name** button (fills the names from `CharacterSpec.random` with a
  fresh RNG); an error label showing the name-related messages from
  `CharacterSpec.validate()`; **Start** is disabled while the spec is invalid; **Back**
  returns to the menu. Start = `CharacterSpec.default_player(content)` with the typed names
  → `Session.new_game(<random seed>, spec)`. Randomness is fine here, because this is
  `game/`, not `sim/`.
- Keyboard: Enter on the name screen = Start (when valid); Esc = Back.

## Acceptance criteria
- [ ] `tests/game/test_launch_options.gd`: every option parses; `skip_menu()` is false with no
  arguments, true with `--screenshot=x`, false with `--menu --screenshot=x`, true with
  `--seed=3`; `--screen=name` is kept.
- [ ] `tools/screenshot.sh out/t0020_menu.png --menu` shows the main menu.
- [ ] `tools/screenshot.sh out/t0020_name.png --menu --screen=name` shows the name screen
  with empty fields and Start disabled.
- [ ] `tools/screenshot.sh out/t0020_game.png` still starts straight in the flat (tools
  unaffected), and the default player is named "Alex".
- [ ] Manual check, described in your notes: `tools/run.sh` shows the menu; type a name,
  Start, then F3 shows the new name. If you can't click in your environment, say so; the
  reviewer will check.
- [ ] `tools/check.sh` passes.

## Implementation notes

## Questions

## Review feedback
