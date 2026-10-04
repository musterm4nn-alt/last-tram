# Art sets for the 2D view

One JSON file per art set: `data/art2d/<set>.json`, picked with `--art=<set>` (T-0080); the game uses `custom` (route B, D35) unless told otherwise, and `--art=placeholder` draws the placeholders. View
only: the sim never reads these files. Anything a set doesn't map, or maps wrongly, draws as
the placeholder, and the problem is printed as a warning. Loaded by `game/view2d/art_set.gd`.

```json
{
  "name": "Kenney",
  "sheets": { "terrain": "res://art/export/kenney/terrain.png", "objects": "res://art/export/kenney/objects.png" },
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

- `sheets`: name → an imported PNG under `res://art/export/`.
- `terrain`: terrain id (from `data/terrain.json`) → `cell` in 16-px tiles. `variants`
  (default 1) takes that many tiles to the right; each map cell picks one by a fixed hash of
  its position, the same every run.
- `objects`: object def id → `rect` `[x, y, w, h]` in sheet pixels for every rotation, or
  `rects` with exactly 4, one per rotation (0–3). A sprite may be larger than the footprint:
  its bottom edge sits on the footprint's bottom edge, centred horizontally.
- `thin_walls` (optional, T-0085): colours of the thin walls the view draws for side and
  bottom walls: any of `top`, `edge`, `face`, `glass` as `"#rrggbb"`. Without it they come
  from the wall tile's average colour. The `wall`, `window` and `door` tiles are drawn only
  where a wall shows its face (the top wall of a room), so draw them as faces.
- `roof` (optional, T-0086): `{ "sheet": ..., "cell": [x, y], "variants": n }`, like a
  terrain: the tile drawn over closed buildings. Without it the view draws shingles.

## Generated source sheets (T-0091)

`--art=imagegen` tries the owner's generated environment and four fixed character designs.
The source PNGs remain unchanged under `art/export/imagegen/`; prompts and original
manifests are under `art/src/imagegen/`. The standard `custom` set remains the default.

- Terrain may use `source_rects: [[x, y, w, h], ...]` instead of `cell`. Each source region
  is sampled with nearest-neighbour into a cached 16-pixel tile; the list provides variants.
- `pattern: [w, h]` samples one source region into a multi-cell image. `pattern_origin`
  sets its phase in map cells; the Imagegen fountain uses a 2 × 2 pattern at [31, 28].
- `background: {"sheet": ..., "rect": [...]}` places an existing source tile under alpha,
  such as grass below a tree or stone below stairs. It repeats once per logical cell.
- Objects may specify a positive logical `size: [w, h]`. Their source `rect`/`rects` can
  then be high resolution, while the sprite still anchors at its footprint's bottom.
- `characters` maps design names to `{ "sheet": ..., "fps": 8, "frames": [...] }`.
  Each of the 16 frames is `{ "rect": [x,y,w,h], "size": [w,h], "offset": [x,y] }`;
  the offset is relative to the person's feet. Rows are south, west, north, east, four
  phases each. `player` is the player design, and other designs are assigned by person id.
  Stopped people use phase 1; actual movement advances walking, running doubles its rate,
  and pause freezes the last pose. Fixed designs are for this visual trial and do not
  reflect every appearance or outfit option.
