---
id: T-0080
title: Art sets in the 2D view
status: done
milestone: Art
size: M
owner: builder
depends_on: []
builder: Claude Code / Opus 5.5
review_rounds: 0
---

## Goal
The 2D view can draw real art instead of the coloured placeholders, one art set at a time,
picked with `--art=<set>`. Anything a set doesn't cover still draws as a placeholder, so art
can arrive gradually and the art gate can compare sets on the same screenshot.

## Read first
`docs/art.md` ("Technical spec", "Mapping art to content"), `game/view2d/world_view_2d.gd`,
`placeholder_tiles.gd`, `object_view_2d.gd`, `game/launch_options.gd`,
`sim/content/content_reader.gd` (reuse it for reading the JSON).

## Scope
- New: `game/view2d/art_set.gd` (`ArtSet`), `data/art2d/README.md` (the format, short),
  `tests/game/test_art_set.gd`, a fixture set in `tests/fixtures/art2d/` (a JSON file and a
  tiny PNG sheet; the PNG is test data, not game art).
- Change: `world_view_2d.gd`, `placeholder_tiles.gd` (only to share the tile set),
  `object_view_2d.gd`, `launch_options.gd` and `main.gd` (`--art`), `docs/art.md` (the format
  is now real).
- **Out of scope:** any real art, people sprites, depth sorting (T-0081), day and night
  (T-0083), a menu option for the art set.

## Specification

**Format** (`data/art2d/<set>.json`; the set id is the file name):
```json
{
  "name": "Placeholder test",
  "sheets": { "terrain": "res://art/export/<set>/terrain.png" },
  "terrain": {
    "grass": { "sheet": "terrain", "cell": [0, 0], "variants": 3 },
    "road":  { "sheet": "terrain", "cell": [3, 0] }
  },
  "objects": {
    "bench":      { "sheet": "objects", "rect": [0, 0, 32, 24] },
    "bed_double": { "sheet": "objects", "rects": [[0, 32, 32, 48], [32, 32, 48, 32], [80, 32, 32, 48], [112, 32, 48, 32]] }
  }
}
```
- `cell` is in 16-px tiles (`ViewConfig.TILE_PX`); `variants` (default 1) takes that many
  tiles to the right, and the view picks one per map cell by a fixed hash of (x, y), the same
  every run.
- An object has `rect` (one image for every rotation) or `rects` (exactly 4, by rotation
  0–3), in sheet pixels. A sprite may be taller or wider than the footprint: it is drawn with
  its bottom edge on the footprint's bottom edge, centred horizontally.

**`class_name ArtSet extends RefCounted`**
- `static func load_set(set_id: String, content: ContentDB, root: String = "res://data/art2d") -> ArtSet`
  — never null; problems go to `errors: Array[String]` (unknown terrain or object id, missing
  sheet name, missing or unloadable PNG, a cell or rect outside its sheet, `rects` not 4
  long, bad numbers). An entry with a problem is dropped and falls back to the placeholder.
  A missing set file gives an empty set with one error.
- `var id: String`, `var errors: Array[String]`
- `func terrain_tile(terrain_id: String, cell: Vector2i) -> Dictionary` — `{}` when not
  mapped, else `{"texture": Texture2D, "region": Rect2i}` (the variant for that map cell).
- `func object_sprite(def_id: String, rotation: int) -> Dictionary` — same shape, `{}` when
  not mapped.
- `static func variant_index(cell: Vector2i, variants: int) -> int` — the fixed hash.
- Sheets are loaded with `load(path) as Texture2D` (they are imported PNGs).

**View:** `WorldView2D` builds its `TileSet` with one atlas source per sheet plus the
placeholder source, and sets each cell from the set or the placeholder. `ObjectView2D`
draws `draw_texture_rect_region` where the set has a sprite (no label), else the placeholder;
the F3 slot dots draw either way. The view holds the active set in a static
`ArtSet` reference (`WorldView2D.art`), set once in `main.gd` from `--art` (default: an empty
set, so everything is a placeholder). Load errors are printed once with `push_warning`.

## Acceptance criteria
- [x] A valid set loads with no errors and returns the right texture and region for terrain
  and for each object rotation → `test_art_set.gd: test_loads_fixture_set`
- [x] Unknown ids, a missing sheet, a rect outside the sheet and a bad `rects` list each give
  an error and fall back → `test_bad_entries_fall_back`
- [x] A missing set file gives an empty set and one error → `test_missing_set`
- [x] `variant_index` is stable and spreads over all variants →
  `test_variant_index_is_stable`
- [x] Sprite placement: bottom on the footprint bottom, centred →
  `test_sprite_rect_anchors_to_footprint` (make the placement a static function on
  `ObjectView2D`)
- [x] `--art=fixture` style parsing → `test_launch_options.gd: test_art_option`
- [x] With no `--art`, the game looks exactly as before → screenshot
  `out/t0080-placeholder.png`, compared by eye with `main`

## Implementation notes
- `game/view2d/art_set.gd` (`ArtSet`): reads the set with `ContentReader`, loads sheets with
  `load()` after `ResourceLoader.exists` (so a missing PNG is an error, not an engine error),
  drops each bad entry with a message. `terrain_tile` / `object_sprite` return
  `{"texture", "region"}` or `{}`; `variant_index` is an integer hash of (x, y).
- `WorldView2D.art` (static, empty by default) is the active set; `main.gd` loads it from
  `--art` and prints load problems with `push_warning`. `WorldView2D.rebuild` adds one atlas
  source per sheet on first use (tiles created on demand) next to the placeholder source.
- `ObjectView2D` draws the sprite where mapped (`sprite_rect`: bottom on the footprint
  bottom, centred, whole pixels), else the old placeholder (moved to `_draw_placeholder`).
  Slot dots draw either way.
- Format documented in `data/art2d/README.md`; `docs/art.md` points to it.
- Fixtures: `tests/fixtures/art2d/sheet.png` (coloured blocks made with a throwaway Godot
  script, test data only), `fixture.json`, `bad.json` (seven different mistakes).

Verified: `tools/check.sh` → 693 passed (new: `test_art_set.gd` ×5,
`test_launch_options.gd: test_art_option`). `out/t0080-placeholder.png` (no `--art`) looks
the same as `main`. A temporary `data/art2d/try.json` (the fixture, not committed) drew the
grass beds in three sheet shades and the benches as taller sprites anchored on their
footprints, with everything else as placeholders (`out/t0080-try.png`).

## Questions

## Review feedback
