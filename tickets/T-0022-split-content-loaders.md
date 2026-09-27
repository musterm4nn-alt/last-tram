---
id: T-0022
title: Split ContentDB into per-domain loader files
status: review
milestone: M1
size: M
owner: builder
depends_on: []
builder: OpenCode / Muse Spark
review_rounds: 0
---

## Goal
Nothing changes in the game. `sim/content/content_db.gd` is about 620 lines after T-0005 and
T-0017 (the conventions say ~300), and T-0001, T-0006 and T-0018 each add more loading to it.
Split it by responsibility so builders work in small files.

## Notes for the architect (to detail before this becomes todo)
- Keep ContentDB's public API exactly as it is (fields, `terrain*()`, `need()`,
  `clothing_def()`, `place_at()`, `errors`, `is_valid()`), so no caller or test changes.
- Move the JSON readers (`_read_json`, `_str`, `_num`, `_bool`, `_arr`, `_obj`,
  `_str_array`) into one reader class that appends to the shared `errors`, and each domain
  (terrain, needs, names, appearance, clothing, world) into its own loader file in
  `sim/content/`. `load_from()` keeps the load order.
- A pure move: the existing content tests (`test_content`, `test_needs`,
  `test_appearance_content`) are the proof. Decide whether a lint test should flag files in
  `sim/` over ~350 lines.
- Schedule it before T-0001, T-0006 and T-0018 add more, and update their "Change:
  ContentDB" scope lines to name the new loader files.

## Implementation notes
Pure move, no behaviour change. `sim/content/content_db.gd` (621 lines) is now 98 lines:
fields, `load_from()`, `is_valid()` and the query methods. New files, all in `sim/content/`:
- `content_reader.gd` (`ContentReader`): the 7 JSON readers as `read_json/read_str/read_num/
  read_bool/read_arr/read_obj/read_str_array` plus `error()`. Errors accumulate in a plain
  `Array[String]` buffer (packed arrays are copied when passed between objects, so loader
  appends to `PackedStringArray` would not stick); `ContentDB.load_from()` drains the buffer
  into its public `errors: PackedStringArray` at the end, in order.
- `terrain_loader.gd`, `needs_loader.gd`, `names_loader.gd`, `appearance_loader.gd`,
  `clothing_loader.gd`, `world_loader.gd`: one `static func load(db, reader, path/dir)` each,
  called from `load_from()` in the original order. Bodies are line-identical to the moved
  code except `_str` -> `reader.read_str` etc. and `errors.append` -> `reader.error`.
- Loaders touch `db`'s lookup tables via `db._terrain_by_id` / `db._need_by_id` directly;
  precedent exists (`sim_rng.gd`, `world_grid.gd`, `world.gd` do the same). No new ContentDB
  API; all public fields, queries, `errors`, `is_valid()`, `load_from()` unchanged.
- `ClothingLoader` reuses `AppearanceLoader.load_color_options` for clothing colours (same
  file shape) instead of duplicating the parser.
- New lint test `tests/lint/test_file_lengths.gd`: fails any `.gd` file under `sim/` over
  350 lines (headroom over the ~300 convention). Decision on the ticket's open question: yes,
  enforced at 350. Largest sim file is now `appearance_loader.gd` at 171 lines.
- Updated scope lines in T-0001 (now `object_loader.gd` + `ObjectLoader.load` in the
  ContentDB spec), T-0006 (now `interaction_loader.gd`) and T-0018 (default player load now
  in `appearance_loader.gd`). Note: T-0018's branch already implements `_load_default_player`
  inside `content_db.gd`, so it will need a rebase onto this split on merge.
- Left stale on purpose (out of scope, needs architect approval): `docs/cookbook.md` "Add a
  new kind of content" still says to add a `_load_<things>()` function inside ContentDB.

Verified: `tools/check.sh` passes — 69 passed, 0 failed, including the unchanged
`test_content`, `test_needs`, `test_appearance_content` (broken-content error strings are
verbatim, error order preserved) and the new lint test. No caller or test file changed.
