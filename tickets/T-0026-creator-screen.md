---
id: T-0026
title: Character creator screen: name, identity, body, face and hair, with a live preview
status: done
milestone: M1
size: M
owner: builder
depends_on: [T-0021]
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
New game opens the character creator instead of the name screen: tabs for Name, Identity
(gender, pronouns, age), Body (height, build, skin tone) and Face & hair (style, colour,
eyes, facial hair, features), and a live preview of the figure from all four directions
that updates with every choice. Start is enabled once the character is valid. (The Clothes
tab and Randomise buttons are T-0029; the portrait is T-0027.)

## Read first
- `docs/design/character-and-appearance.md` → "The character creator"
- T-0021 as merged: `game/ui/creator_model.gd` (`CreatorModel`)
- As merged: `game/ui/name_screen.gd` and `tests/game/test_name_screen.gd` (the Name tab
  keeps all their behaviour), `game/main.gd` (`_show_name_screen`, `_start_named_game`,
  `_show_menu`), `game/launch_options.gd` (`--screen=name`),
  `game/view2d/person_drawer_2d.gd` (`PersonDrawer2D.draw(canvas, content, appearance,
  outfit, facing, px, is_player)`, feet at (0, 0))

## Scope
Create `game/ui/character_creator.gd` (`CharacterCreator`), `game/ui/figure_preview.gd`
(`FigurePreview`), `tests/game/test_character_creator.gd`. Change `game/main.gd`,
`game/launch_options.gd`, `tests/game/test_launch_options.gd`. Delete
`game/ui/name_screen.gd` and `tests/game/test_name_screen.gd` **after** porting every one of
their tests to `test_character_creator.gd` (same checks, on the creator's Name tab).
**Out of scope:** the Clothes tab and Randomise buttons (T-0029), the portrait (T-0027).

## Specification

### `CharacterCreator` (`extends CanvasLayer`, `layer = 21`, like `NameScreen`)
- Same signals as `NameScreen`: `start_pressed(spec: CharacterSpec)`, `back_pressed`, and
  `focus_first_field()`. It owns a `CreatorModel` (`var model: CreatorModel`).
- Layout: a dimmed background; a centred panel with a `TabContainer` on the left (tabs
  "Name", "Identity", "Body", "Face & hair") and the `FigurePreview` on the right; below, the
  error/hint label and Start / Back buttons, exactly like `NameScreen`.
- **Name tab:** the three name fields and "Random name" from `NameScreen`, with the same
  hint and error rules (empty fields show the grey hint, typed invalid names show errors).
- **Identity tab:** pickers for gender and pronouns, and an age `SpinBox` (18–80).
- **Body tab:** a height `SpinBox` (150–205, "cm" suffix), pickers for build and skin tone.
- **Face & hair tab:** pickers for hair style, hair colour, eye colour and facial hair, and
  one `CheckBox` per feature.
- A **picker** is one row: a label, a "◀" button, the current option's display name
  (the catalog option's `name`), and a "▶" button, calling `model.previous/next(field)`.
  Build it with one helper so every picker is the same.
- Every change updates the preview and the Start button (`model.errors()` empty).
- Keyboard (lessons from T-0020, keep them): ignore input while hidden; Esc = Back even
  while a text field is focused (handle it in `_input`); Enter = Start when valid;
  `keep_editing_on_text_submit` on text fields; `focus_first_field()` when shown.

### `FigurePreview` (`extends Control`)
- `func show_spec(spec: CharacterSpec) -> void` stores the spec and redraws.
- `_draw()`: the figure four times side by side (facing down, left, up, right), each with
  `PersonDrawer2D.draw(self, Session.content, spec.appearance, spec.outfit, facing,
  PREVIEW_PX, false)` using `draw_set_transform` to place each figure's feet.
  `const PREVIEW_PX: float = 96.0`; minimum size 4 × 96 × 1.1 by 2.2 × 96 px.

### main.gd and launch options
- `main.gd` shows the `CharacterCreator` where it showed the `NameScreen` (same signals).
- `--screen=creator` opens it directly (like `--screen=name` did; `--screen=name` now opens
  the creator too, on the Name tab). `--creator-tab=<name|identity|body|face>` selects the
  tab. `--creator-seed=N` (tests and screenshots only): start the model from
  `CharacterSpec.random(content, rng seeded N)`.

## Acceptance criteria (`tests/game/test_character_creator.gd` unless named)
- [ ] Every test from `test_name_screen.gd`, ported to the creator's Name tab, passes (list
  them in the notes, old name → new name).
- [ ] Pressing a picker's ▶ changes the model and the shown option name (test one picker per
  tab); the age and height spin boxes change the model within their limits.
- [ ] Ticking a feature checkbox adds it to the model; unticking removes it.
- [ ] Start stays disabled while the names are empty and emits `start_pressed` with the
  model's spec once they are valid (and gender, look... are the ones chosen).
- [ ] `test_launch_options.gd`: `--screen=creator`, `--creator-tab=body`, `--creator-seed=7`
  parse.
- [ ] Screenshots (open and look at each): `tools/screenshot.sh out/t0026_<tab>.png
  --screen=creator --creator-tab=<tab> --creator-seed=7` for name, identity, body and face:
  each shows its tab and the four-direction preview of the same character.
- [ ] `tools/check.sh` passes.

## Implementation notes
Built by the architect (Claude Code / Opus 5.5) at the owner's request.
- `game/ui/character_creator.gd` (`CharacterCreator`): tabs Name, Identity, Body,
  Face & hair; one `_picker()` helper for every list field; age and height `SpinBox`es;
  feature checkboxes; `_sync_from_model()` refreshes every control (without re-firing
  their signals), the preview and Start. Keeps every NameScreen rule (hint vs errors,
  Esc in `_input`, Enter only while visible, `keep_editing_on_text_submit`).
  `start_from(spec)` for seeded screenshots (the name fields start from the model, so a
  seeded character keeps its names).
- `game/ui/figure_preview.gd` (`FigurePreview`): the figure four times (Front, Left, Back,
  Right, labelled) on a mid-grey floor, so black and white clothes both show (the first
  screenshots were on near-black and dark trousers vanished).
- `CreatorModel.option_name(field, id)` gives pickers the catalog's display names.
- `main.gd`: New game opens the creator; `--screen=creator` (and `--screen=name`),
  `--creator-tab`, `--creator-seed`.
- `game/ui/name_screen.gd` and its test are gone. All six tests were ported to
  `tests/game/test_character_creator.gd` under the same names:
  test_starts_empty_with_start_disabled_and_a_hint, test_typed_names_start_with_the_default_look,
  test_bad_name_disables_start_and_shows_error, test_empty_nickname_is_fine,
  test_hidden_screen_ignores_enter, test_esc_goes_back_even_while_typing. Five new tests
  cover pickers, the spin boxes, feature checkboxes, Start with a chosen look and a seeded
  start.
- Godot trap found (added to `docs/conventions.md`): outside the tree, `Range` controls
  don't emit `value_changed` when `value` is set, so the tests emit it the way a player's
  change does.
- `tools/check.sh`: 273 passed, 0 failed.
- Screenshots `out/t0026_{name,identity,body,face}.png` (`--creator-seed=7`): each tab
  with the same character (Sven de Vries, non-binary, they/them, 66, 185 cm, slim, bald
  with stubble, dressed in red) in the labelled four-way preview.
- For later: the placeholder figure draws facial hair centred in the side views too.

## Questions

## Review feedback

Architect-built; self-reviewed with the checks above (no separate review round).
