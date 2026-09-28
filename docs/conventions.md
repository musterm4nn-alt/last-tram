# Conventions

How code, data, tests and commits look in this repo. For step-by-step recipes see
[cookbook.md](cookbook.md).

## GDScript

- Follow the official GDScript style guide: tabs, `snake_case` for functions, variables and
  files, `PascalCase` for classes, `CONSTANT_CASE` for constants.
- One class per file; the file name is the snake_case of its `class_name`
  (`MovementSystem` → `movement_system.gd`). Reusable classes get a `class_name`.
- Every class starts with a `##` doc comment saying what it is for. Document public functions
  whose purpose isn't obvious from the name.
- Keep files under ~300 lines. Split by responsibility when they grow.
- Don't leave dead code, commented-out code or debug prints behind.

### Static typing is mandatory

Untyped declarations are **compile errors** in this project. Type every variable, parameter,
return value, and every `for` variable when iterating something untyped:

```gdscript
var speed: float = 4.5
var cell := Vector3i(3, 4, 0)            # := is fine when the type is obvious
func cell_of(p: Person) -> Vector3i:
for person: Person in world.people.values():
for key: Variant in some_dictionary:
for i: int in 10:                         # range loops over ints are typed automatically too
```

### Godot 4 gotchas that have bitten this project

| Trap | Do this |
|---|---|
| `"%s" % my_array` treats the array as the list of arguments | `"%s" % [my_array]` |
| JSON has no ints: `JSON.parse_string("1")` gives `1.0` | `int(d["id"])`, `Ser.to_vec2(...)` when loading |
| `{"a": 1} == {"a": 1.0}` is **false** | Compare JSON text (`Ser.to_json`) or convert first |
| `==` between different types can raise a runtime error | Check `typeof` first (see `TestCase._equal`) |
| `JSON.parse_string()` logs an error on bad input, which fails tests | `var json := JSON.new(); json.parse(text)` |
| Global function names used as variables (`log`, `seed`, `char`, `str`, `range`, `hash`) | Pick another name |
| Packed arrays (`PackedStringArray`...) are copied when passed; `Array`/`Dictionary` are shared | Return packed arrays; don't expect callee changes to stick |
| A new `class_name` isn't known until Godot re-imports | Run `tools/check.sh` (it imports) after adding files |
| Godot exits with code 0 even if a script fails to parse | Trust the `LAST_TRAM_TESTS:` line, which the tools check for you |
| Int division is intended; its warning is off | `a / b` with ints floors; use `float(a) / b` when you need a fraction |
| A popup (`PopupMenu`, any `Window`) under a world `Node2D` inherits the camera's zoom | Add popups under a `CanvasLayer` (e.g. the HUD) |
| Popups close when the window's focus changes, which happens a few frames after startup | Launch options that open a popup wait ~12 frames |

## sim/ rules (the most important section)

1. `extends RefCounted` (or another sim class). No `Node`, no scenes, no signals.
2. Never use `Input`, `OS`, `Time`, `Engine`, `get_tree()`, `await`, or anything under
   `res://game/`. Only `sim/content/` may read files.
3. Randomness only via `sim.rng.stream("<your system>")`. Never `randi()`, `randf()` or
   `randomize()`.
4. Entities are referenced by **int id** in saved state. No object references stored across
   entities. Look things up with `world.get_person(id)`.
5. Every state field is saved in `to_dict()` and restored in `from_dict()`. Transient helper
   fields (like `Person.prev_pos`) are marked `## NOT saved` and never affect logic.
6. Systems (`SimSystem`) keep no state; caches must be rebuildable from World.
7. Report what happened with `sim.emit_event(&"thing_happened", {...})` (snake_case, past
   tense, ids in data).
8. Changes from outside arrive as Commands (`sim/commands/`), registered in `CommandRegistry`.
9. Numbers that tune gameplay (rates, speeds, thresholds) go in `data/` JSON, not constants,
   once they're more than a placeholder.

`tests/lint/test_sim_purity.gd` enforces rules 1–3. Reviews enforce the rest.

## game/ rules

- Read sim state freely; **never assign to it**. Change the sim only with
  `Session.submit(SomeCommand.new(...))`. Only `Session` steps the sim.
- Build node trees and UI in code (`Node.new()`, `add_child`), not in hand-edited `.tscn`.
- Views rebuild everything on `Session.game_loaded`, then follow `Session.sim_event`.
- Pixels exist only here: convert cells with `ViewConfig.TILE_PX`.
- New input actions go in `InputActions.KEYS` (physical keys).

## data/ rules

- JSON with tab indentation. A `"_doc"` key at the top explains the file and is ignored by
  the loader.
- `id`: `snake_case`, unique within its kind, never renamed once saves may contain it
  (renaming needs a save migration). `name`: human-readable English.
- Every field is read through `ContentDB`'s `_str/_num/_bool/_arr` readers and validated,
  including references to other ids. A new field without validation isn't finished.
- District maps: all rows the same length; glyphs from `data/terrain.json`; no trailing
  whitespace (editors strip it, so don't rely on spaces at row ends).
- Content never contains art paths or pixel sizes. Only `debug_color` is allowed.

## Tests

- Location: `tests/sim/` for sim behaviour, `tests/game/` for view/UI logic that can be tested
  headless, `tests/lint/` for architecture rules. File `test_<topic>.gd`, `extends TestCase`.
- Name tests after the behaviour: `test_wall_stops_person_just_before_it`, not `test_move2`.
- Build tiny worlds with `SimFactory.from_rows(content(), ["#####", "#@..#", "#####"])`.
  `content()` is the shared real content.
- Step time with `sim.step()`, `sim.run_steps(n)`, `sim.run_minutes(n)`. No real time, no
  `await`.
- Every acceptance criterion in a ticket maps to at least one test. Invariants ("never walks
  through walls", "needs stay in 0..100") get property tests with many random inputs from a
  fixed seed.
- Tests must be deterministic and fast (the whole suite should stay under ~20 s).
- A test fails if any error is logged while it runs, so don't expect errors. Code that
  handles bad input should return errors, not `push_error`.
- **Never** delete, skip or loosen a test to make it pass. If a test is wrong, say why in the
  ticket notes and let the reviewer decide.

## Git

- Branch per ticket: `t/0007-short-slug`. Builders never commit to `main`.
- Commit messages: `T-0007: what changed`, in the imperative mood. Several commits per
  ticket are fine.
- The pre-commit hook runs `tools/check.sh`. **Never** use `--no-verify`.
- Commit the `.uid` files Godot creates next to new scripts.
- Don't commit `out/` or `.godot/` (they are ignored).
