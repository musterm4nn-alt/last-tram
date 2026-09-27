---
id: T-0020
title: Main menu, launch options, and choosing your name
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0019]
builder: OpenCode / Muse Spark 1.3 Free
review_rounds: 1
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
Implemented on branch `t/0020-main-menu-and-name`, stacked on unmerged
`t/0019-draw-appearance` (rebase onto main once the stack merges).
- New: `game/launch_options.gd` (`LaunchOptions.parse(PackedStringArray)`, `skip_menu()`
  exactly per spec: `menu` forces the menu; otherwise any of quickstart, screenshot,
  load, advance > 0, walk, random-character, seed_given skips it).
- New: `game/ui/main_menu.gd` (full-screen dark `LAST TRAM` + subtitle + New game /
  Continue / Quit; Continue disabled when no quicksave exists; closes itself on
  `Session.game_loaded`) and `game/ui/name_screen.gd` (First/Last/Nickname fields
  prefilled with Alex Novak, Random name via `CharacterSpec.random` with a fresh RNG,
  error label with the name messages from `CharacterSpec.validate()`, Start disabled
  while invalid, Back; Enter = Start, Esc = Back; Start emits the typed names on the
  default spec and main starts `Session.new_game(randi(), spec)`).
- Changed: `game/main.gd` parses once into `LaunchOptions`, keeps today's quickstart
  behaviour, otherwise shows the menu (and the name screen directly for
  `--screen=name`); HUD and debug overlay stay hidden until `Session.game_loaded`.
  Option docs at the top updated. Removed the old `_parse_args`.
- Tests: `tests/game/test_launch_options.gd` (all criteria cases) and
  `tests/game/test_name_screen.gd` (prefill starts, bad name disables + errors, empty
  nickname fine). Note: the screen test calls `_ready()` directly and seeds
  `Session.content` because the Session autoload isn't readied before tests run.
- Verified: `tools/check.sh` → 92 passed, 0 failed.
- Screenshots (all opened and inspected):
  - `out/t0020_menu.png` (`--menu`): dark screen, LAST TRAM title, subtitle, New game
    (focused) / greyed-out Continue / Quit. Matches.
  - `out/t0020_name.png` (`--menu --screen=name`): "Your character" panel, First name
    Alex / Last name Novak / empty Nickname, Random name, Start + Back. Matches.
  - `out/t0020_game.png` (no options): straight into the flat with HUD, no menu.
    Matches (screenshot implies `--screenshot`, which skips the menu, so tools are
    unaffected).
  - `out/t0020_debug.png` (`--debug`): overlay shows `player #1 Alex (27)` — the
    quickstart default player is still Alex. Matches.
- Manual check: I cannot click in this environment, so typing a name + Start + F3 is
  NOT verified by me — screenshots prove the menu and name screen render and the
  Start-enabling logic is unit-tested, but the reviewer must click through `tools/run.sh`.

## Questions

## Review feedback

**Round 1 (architect): passed.** Launch options, `skip_menu()`, the menu, Continue and
the tools' quick start all work as specified. The reviewer drove the real game with
simulated mouse and keyboard (xdotool on Xvfb): New game, typing a name, Start, F3 shows
the typed name; F5, relaunch, Continue loads it; Random name fills valid names. No script
errors, including gameplay keys pressed on the menu. Reviewer fixes, made before merging:
- **The name fields start empty** (the owner's intent: the player names their character;
  the ticket was clarified after this branch started, so this is not a builder mistake).
  An untouched form shows a grey hint ("Type a first and last name, or press Random
  name.") instead of red errors; typed invalid names still show red errors.
- Start is disabled while the spec has *any* problem (the spec), not only name problems.
- The hidden name screen reacted to Enter/Esc while the menu was showing (Enter could
  start a game as the stand-in without ever seeing the name screen); it now ignores input
  while hidden.
- Keyboard flow: the cursor starts in First name (`NameScreen.focus_first_field()`); Esc
  goes back even while a field is being edited (handled in `_input`); fields keep editing
  after Enter on an unfinished form (`keep_editing_on_text_submit`); back on the menu,
  New game is selected again (`MainMenu.focus_new_game()`).
- Tests: `test_name_screen.gd` rewritten for the empty start, typed names starting with the
  default look, a hidden screen ignoring Enter, and Esc; mutation checks confirmed they
  fail without the fixes.
