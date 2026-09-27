---
id: T-0022
title: Split ContentDB into per-domain loader files
status: todo
milestone: M1
size: M
owner: builder
depends_on: []
builder:
review_rounds: 0
---

## Goal
Nothing changes in the game. `sim/content/content_db.gd` is 636 lines (the conventions say
~300), and T-0001 and T-0006 are about to add more loading to it. Move each kind of content
into its own small loader file, keep `ContentDB`'s public API exactly as it is, and add a
lint test so no code file grows past 400 lines again.

## Read first
- `AGENTS.md`, `docs/conventions.md`
- `sim/content/content_db.gd` (all of it: you move almost every function out of it)
- `tests/sim/test_content.gd`, `tests/sim/test_needs.gd`, `tests/sim/test_appearance_content.gd`
  (they check loading and the exact error messages; they must pass **unchanged**)
- `tests/lint/test_sim_purity.gd` and `tests/lint/lint_util.gd` (pattern for the new lint test)

## Scope
Create in `sim/content/`:
- `content_reader.gd` (`ContentReader`)
- `terrain_loader.gd` (`TerrainLoader`), `needs_loader.gd` (`NeedsLoader`),
  `names_loader.gd` (`NamesLoader`), `appearance_loader.gd` (`AppearanceLoader`),
  `clothing_loader.gd` (`ClothingLoader`), `world_loader.gd` (`WorldLoader`)

Create tests: `tests/sim/test_content_reader.gd`, `tests/lint/test_file_size.gd`.

Change: `sim/content/content_db.gd` (keep only what "ContentDB after the split" lists),
`docs/cookbook.md` (replace one section with the text below; this ticket allows that edit).

**Out of scope:** any change to what is loaded, to validation rules or to error messages;
any caller of `ContentDB` (nothing outside `sim/content/` changes); `docs/architecture.md`
and `docs/decisions.md` (the architect updates them when merging).

## Specification

### Rules for the move
- **Move code, don't rewrite it.** Every validation check and every error message stays
  byte-for-byte the same (the tests match the messages). Only these edits are allowed:
  `errors.append(...)` becomes `r.error(...)`; reader calls are renamed (table below); fields
  of the database are reached through `r.db` (for example `appearance.age_min` becomes
  `r.db.appearance.age_min`); the terrain and need indexes are filled through
  `r.db.add_terrain(t)` / `r.db.add_need(n)`; private helpers become private static functions
  of their loader (leading underscore) that take `r: ContentReader` as their first argument.
- The load order stays exactly the same.
- Every new class: `extends RefCounted`, a `##` class doc, typed everything. Loaders have
  **static functions only** and no state.

### `ContentReader` (`sim/content/content_reader.gd`)
```gdscript
class_name ContentReader
extends RefCounted
## Reads content files for ContentDB's loaders. Never crashes: every problem is added to
## the database's `errors` (through error()) and a harmless default is returned.

## The database being loaded; loaders store their results in it.
var db: ContentDB

func _init(p_db: ContentDB) -> void
## Records a content problem, e.g. "data/needs.json: need 'fun': 'start' must be within 0..100".
func error(message: String) -> void                                   # db.errors.append(message)
func read_json(path: String) -> Variant                               # was ContentDB._read_json
func read_rows(path: String) -> PackedStringArray                     # was _read_rows
func read_str(d: Dictionary, key: String, ctx: String) -> String      # was _str
func read_num(d: Dictionary, key: String, ctx: String) -> float       # was _num
func read_bool(d: Dictionary, key: String, ctx: String) -> bool       # was _bool
func read_arr(d: Dictionary, key: String, ctx: String) -> Array       # was _arr
func read_obj(d: Dictionary, key: String, ctx: String) -> Dictionary  # was _obj
func read_str_array(d: Dictionary, key: String, ctx: String) -> PackedStringArray   # was _str_array
## A list of {"id", "name"} entries (hair styles, builds...), in file order.
func read_named_options(entries: Variant, ctx: String) -> Dictionary[String, NamedOption]  # was _load_named_options
## A list of {"id", "name", "color", "natural"?} entries (skin tones, clothing colours...).
func read_color_options(entries: Variant, ctx: String) -> Dictionary[String, ColorOption]  # was _load_color_options
```

### Loaders (where each old function goes)
| Old `ContentDB` function | New home |
|---|---|
| `_load_terrains(path)` | `TerrainLoader.load_terrains(r: ContentReader, path: String) -> void` |
| `_load_needs(path)` | `NeedsLoader.load_needs(r: ContentReader, path: String) -> void` |
| `_load_names(path)`, `_name_list(value, ctx)` | `NamesLoader.load_names(r, path)`, `NamesLoader._name_list(r, value, ctx)` |
| `_load_appearance(path)`, `_load_genders(...)`, `_load_pronouns(...)` | `AppearanceLoader.load_appearance(r, path)`, `AppearanceLoader._genders(r, entries, ctx)`, `AppearanceLoader._pronouns(r, entries, ctx)` |
| `_load_default_player(path)` | `AppearanceLoader.load_default_player(r, path)` |
| `_load_clothing(dir)`, `_load_clothing_colours(path)`, `_load_clothing_items(path)` | `ClothingLoader.load_clothing(r, dir)`, `ClothingLoader._colours(r, path)`, `ClothingLoader._items(r, path)` |
| `_load_world(world_dir)`, `_load_district(dir, id)`, `_validate_rows(rows, ctx)`, `_validate_spawn(district, local, ctx)` | `WorldLoader.load_world(r, world_dir)`, `WorldLoader._district(r, dir, district_id)`, `WorldLoader._validate_rows(r, rows, ctx)`, `WorldLoader._validate_spawn(r, district, local, ctx)` |
| `_load_named_options`, `_load_color_options`, `_read_json`, `_read_rows`, `_str`, `_num`, `_bool`, `_arr`, `_obj`, `_str_array` | `ContentReader` (above) |

Duplicate checks that used the private indexes now use the public queries, with the same
meaning: `_terrain_by_id.has(t.id)` → `r.db.terrain_index(t.id) >= 0`;
`_terrain_by_glyph.has(t.glyph)` → `r.db.terrain_index_for_glyph(t.glyph) >= 0`;
`_need_by_id.has(n.id)` → `r.db.need(n.id) != null`.

### `ContentDB` after the split
Keeps: the class doc (replace the 4-step "how to add content" list with one line: "To add a
new kind of content, see docs/cookbook.md → Add a new kind of content."), `DATA_ROOT`,
`FIRST_NAME_LISTS`, every public field, the three private indexes, `load_default()`,
`is_valid()`, and every query (`terrain_index`, `terrain_index_for_glyph`, `terrain`,
`need`, `place_at`, `clothing_def`). Adds:
```gdscript
## Appends a terrain and indexes its id and glyph. TerrainLoader reports duplicates first.
func add_terrain(t: TerrainDef) -> void     # _terrain_by_id[t.id] = terrains.size(); same for the glyph; then terrains.append(t)

## Appends a need and indexes its id. NeedsLoader reports duplicates first.
func add_need(n: NeedDef) -> void           # _need_by_id[n.id] = n; needs.append(n)
```
`load_from()` becomes:
```gdscript
func load_from(root: String) -> void:
	var r := ContentReader.new(self)
	TerrainLoader.load_terrains(r, root.path_join("terrain.json"))
	NeedsLoader.load_needs(r, root.path_join("needs.json"))
	NamesLoader.load_names(r, root.path_join("names").path_join("names.json"))
	AppearanceLoader.load_appearance(r, root.path_join("appearance").path_join("appearance.json"))
	ClothingLoader.load_clothing(r, root.path_join("clothing"))
	WorldLoader.load_world(r, root.path_join("world"))
	AppearanceLoader.load_default_player(r, root.path_join("appearance").path_join("default_player.json"))
```

### Lint: `tests/lint/test_file_size.gd`
```gdscript
extends TestCase
## Guards docs/conventions.md: code files stay small enough to read in one go.

const MAX_LINES: int = 400
const CODE_DIRS: Array[String] = ["res://sim", "res://game", "res://tools"]

func test_code_files_stay_small() -> void
	# for every file from LintUtil.gd_files(dir) in CODE_DIRS: count lines
	# (FileAccess.get_file_as_string(path).split("\n").size()); if > MAX_LINES:
	# fail("%s has %d lines (max %d): split it by responsibility (docs/conventions.md)")
```
**Write this test first** and run it on the unchanged code: it must fail on
`sim/content/content_db.gd`. Paste that failure line into your notes.

### Tests: `tests/sim/test_content_reader.gd`
- `test_readers_report_into_the_db_and_return_defaults`: with `db := ContentDB.new()` and
  `r := ContentReader.new(db)`: `r.read_str({}, "id", "ctx")` returns `""` and `db.errors`
  contains `"ctx: 'id' must be a string"`; `r.read_num({"n": "x"}, "n", "ctx")` returns `0.0`
  and adds `"ctx: 'n' must be a number"`; `r.read_json("res://no/such.json")` returns `null`
  and adds `"res://no/such.json: file not found"`.
- `test_add_terrain_indexes_id_and_glyph`: add two `TerrainDef`s (ids "grass" / "stone",
  glyphs "," / "#"); `terrain_index("stone") == 1`, `terrain_index_for_glyph(",") == 0`,
  `terrain_index("mud") == -1`.

### `docs/cookbook.md`: replace the section "Add a new kind of content" with
```markdown
### Add a new kind of content (objects, interactions, jobs...)

1. `sim/content/<thing>_def.gd` with typed fields and `##` docs.
2. `data/<things>.json` (or a folder of files) with a `"_doc"` key.
3. `sim/content/<thing>_loader.gd`: a `<Thing>Loader` (RefCounted, static functions only)
   with `static func load_<things>(r: ContentReader, path: String) -> void`. Read every
   field through the reader (`r.read_str/read_num/read_bool/read_arr/read_obj/
   read_str_array`), report problems with `r.error("<file>: <thing> '<id>': <problem>")`,
   validate every reference (for example, an interaction's `object_tags` must exist on some
   object) and store the results in `r.db`. Copy `sim/content/needs_loader.gd`.
4. In `ContentDB`: a field `things: Dictionary[String, ThingDef]`, a query
   `thing(id) -> ThingDef` (null if unknown), and one line in `load_from()` that calls the
   loader after everything it references.
5. Tests: the real data loads without errors (`test_content.gd`), and a broken example in
   `tests/fixtures/content_broken/` is reported with a clear message.
```

## Acceptance criteria
- [ ] `tools/check.sh` passes, and **no existing test file is changed** (`git diff main --stat
  -- tests/` shows only the two new files). The content tests prove that loading and every
  error message are unchanged.
- [ ] `sim/content/content_db.gd` is at most 150 lines and has no `_load_*`, `_read_*`,
  `_str`/`_num`/`_bool`/`_arr`/`_obj`/`_str_array` or `_validate_*` functions left.
- [ ] Every new file is at most 250 lines and starts with a `##` class doc.
- [ ] `tests/lint/test_file_size.gd` passes now; your notes show it failing on the old
  `content_db.gd` (write it first).
- [ ] `tests/sim/test_content_reader.gd` passes (the two tests above).
- [ ] `docs/cookbook.md` has the new "Add a new kind of content" section.
- [ ] `tools/simrun.sh --days=1` still ends with `LAST_TRAM_SIMRUN: OK`.

## Implementation notes

## Questions

## Review feedback
